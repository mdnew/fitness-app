#!/usr/bin/env node
/**
 * ExerciseDB GIF fetcher — matches app exercises to ExerciseDB v1 and downloads GIFs.
 *
 * Run from this directory:
 *   node fetch-exercise-gifs.js
 *
 * Uses https://www.exercisedb.dev/api/v1 (free, no API key). See README.md for RapidAPI / fallbacks.
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

const CONFIG = {
  source: 'v1',
  rapidApiKey: 'YOUR_RAPIDAPI_KEY_HERE',
  outputDir: path.join(__dirname, 'exercise-gifs'),
  mappingFile: path.join(__dirname, 'exercise-mapping.json'),
};

// ExerciseDB returns an error payload (no `data`) for non-browser user agents.
const DEFAULT_HEADERS = {
  Accept: 'application/json',
  'User-Agent':
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
};

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function fetchJSON(url, headers = {}, attempt = 0) {
  return new Promise((resolve, reject) => {
    const parsedUrl = new URL(url);
    const options = {
      hostname: parsedUrl.hostname,
      path: parsedUrl.pathname + parsedUrl.search,
      headers: { ...DEFAULT_HEADERS, ...headers },
    };
    https
      .get(options, (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', async () => {
          if (res.statusCode === 429 && attempt < 8) {
            const delayMs = Math.min(30_000, 2000 * 2 ** attempt);
            console.warn(`  Rate limited (429), retrying in ${delayMs / 1000}s...`);
            await sleep(delayMs);
            try {
              resolve(await fetchJSON(url, headers, attempt + 1));
            } catch (e) {
              reject(e);
            }
            return;
          }
          if (res.statusCode !== 200) {
            reject(new Error(`HTTP ${res.statusCode}: ${data.slice(0, 200)}`));
            return;
          }
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(new Error(`JSON parse error: ${data.slice(0, 200)}`));
          }
        });
      })
      .on('error', reject);
  });
}

function downloadFile(url, dest, headers = {}) {
  return new Promise((resolve, reject) => {
    const parsedUrl = new URL(url);
    const options = {
      hostname: parsedUrl.hostname,
      path: parsedUrl.pathname + parsedUrl.search,
      headers: { ...DEFAULT_HEADERS, ...headers },
    };
    const file = fs.createWriteStream(dest);
    https
      .get(options, (res) => {
        if (res.statusCode === 301 || res.statusCode === 302) {
          file.close();
          try {
            fs.unlinkSync(dest);
          } catch (_) {}
          return downloadFile(res.headers.location, dest, headers).then(resolve).catch(reject);
        }
        if (res.statusCode !== 200) {
          file.close();
          try {
            fs.unlinkSync(dest);
          } catch (_) {}
          return reject(new Error(`HTTP ${res.statusCode}`));
        }
        res.pipe(file);
        file.on('finish', () => {
          file.close();
          resolve();
        });
      })
      .on('error', (e) => {
        try {
          fs.unlinkSync(dest);
        } catch (_) {}
        reject(e);
      });
  });
}

async function fetchAllExercisesV1() {
  const BASE = 'https://www.exercisedb.dev/api/v1';
  const pageSize = 100;
  let offset = 0;
  const all = [];
  let expectedTotal = Infinity;

  console.log('Fetching exercise list from ExerciseDB v1 (paginated)...');
  for (;;) {
    const url = `${BASE}/exercises?limit=${pageSize}&offset=${offset}`;
    const res = await fetchJSON(url);
    if (res.success === false || (res.error && !Array.isArray(res.data))) {
      throw new Error(
        `ExerciseDB API rejected the request (check User-Agent / network). Response: ${JSON.stringify(res).slice(0, 300)}`
      );
    }
    if (typeof res.metadata?.totalExercises === 'number') {
      expectedTotal = res.metadata.totalExercises;
    }
    const chunk = Array.isArray(res.data) ? res.data : [];
    if (chunk.length === 0) break;
    all.push(...chunk);
    offset += pageSize;
    if (all.length >= expectedTotal) break;
    if (chunk.length < pageSize) break;
    await sleep(400);
  }

  if (all.length < expectedTotal) {
    console.warn(
      `Warning: got ${all.length} exercises but API reports totalExercises=${expectedTotal}. Matches may be incomplete.`
    );
  }
  console.log(`Loaded ${all.length} exercises from API`);
  return all;
}

function matchScore(normalized, dbLower) {
  if (!normalized || !dbLower) return 0;
  if (dbLower === normalized) return 1000 + normalized.length;
  // Strong: database name contains the full search phrase (e.g. "cable crunch" ⊆ "kneeling cable crunch")
  if (normalized.length >= 4 && dbLower.includes(normalized)) {
    return 800 + normalized.length;
  }
  // Weak: search phrase contains a long db name (blocks accidental "run", "sit", etc.)
  if (dbLower.length >= 8 && normalized.includes(dbLower)) {
    return 400 + dbLower.length;
  }
  return 0;
}

function bestMatchForTerms(terms, dbList) {
  let bestDb = null;
  let bestScore = 0;
  const sorted = [...terms].filter(Boolean).sort((a, b) => b.length - a.length);
  for (const term of sorted) {
    const normalized = term.toLowerCase().trim();
    for (const db of dbList) {
      const s = matchScore(normalized, db.name?.toLowerCase() ?? '');
      if (s > bestScore) {
        bestScore = s;
        bestDb = db;
      }
    }
  }
  return { bestDb, bestScore };
}

function matchExerciseToDb(ex, dbList) {
  const primary = bestMatchForTerms([ex.exercisedb_name], dbList);
  if (primary.bestScore >= 800) return primary.bestDb;

  const alts = bestMatchForTerms(ex.alt_search_terms, dbList);
  const pick = alts.bestScore > primary.bestScore ? alts : primary;
  if (pick.bestScore < 400) return null;
  return pick.bestDb;
}

async function fetchFromV1(exercises) {
  const dbList = await fetchAllExercisesV1();
  return exercises.map((ex) => {
    const match = matchExerciseToDb(ex, dbList);
    return {
      ...ex,
      matched: !!match,
      db_name: match?.name ?? null,
      db_id: match?.exerciseId ?? match?.id ?? null,
      gifUrl: match?.gifUrl ?? match?.imageUrl ?? null,
      targetMuscles: match?.targetMuscles ?? [],
      bodyParts: match?.bodyParts ?? [],
      equipments: match?.equipments ?? [],
      secondaryMuscles: match?.secondaryMuscles ?? [],
      instructions: match?.instructions ?? [],
    };
  });
}

async function fetchFromRapidAPI(exercises) {
  const BASE = 'https://exercisedb.p.rapidapi.com';
  const headers = {
    'X-RapidAPI-Key': CONFIG.rapidApiKey,
    'X-RapidAPI-Host': 'exercisedb.p.rapidapi.com',
  };

  console.log('Fetching from ExerciseDB via RapidAPI...');
  const results = [];

  for (const ex of exercises) {
    const searchTerm = encodeURIComponent(ex.exercisedb_name || ex.app_name);
    try {
      const data = await fetchJSON(`${BASE}/exercises/name/${searchTerm}?limit=5`, headers);
      const matches = Array.isArray(data) ? data : [];
      const match = matches[0] || null;

      results.push({
        ...ex,
        matched: !!match,
        db_name: match?.name || null,
        db_id: match?.id || null,
        gifUrl: match?.gifUrl || null,
      });

      await new Promise((r) => setTimeout(r, 200));
    } catch (e) {
      console.error(`  Error searching "${ex.app_name}": ${e.message}`);
      results.push({ ...ex, matched: false, db_name: null, db_id: null, gifUrl: null });
    }
  }

  return results;
}

async function fetchFromFreeDB(exercises) {
  const JSON_URL = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json';
  const IMG_BASE = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises';

  console.log('Fetching from free-exercise-db...');
  const allExercises = await fetchJSON(JSON_URL);
  console.log(`Found ${allExercises.length} exercises`);

  return exercises.map((ex) => {
    const searchTerms = [ex.free_exercise_db_name, ex.app_name, ...ex.alt_search_terms].filter(Boolean);
    let match = null;
    for (const term of searchTerms) {
      const normalized = term.toLowerCase().trim();
      match = allExercises.find(
        (db) =>
          db.name?.toLowerCase() === normalized ||
          db.name?.toLowerCase().includes(normalized) ||
          normalized.includes(db.name?.toLowerCase())
      );
      if (match) break;
    }

    if (match && match.images?.length > 0) {
      return {
        ...ex,
        matched: true,
        db_name: match.name,
        db_id: match.id,
        gifUrl: null,
        imageUrls: match.images.map((img) => `${IMG_BASE}/${img}`),
        note: 'free-exercise-db has JPG images only (no animated GIFs)',
      };
    }
    return { ...ex, matched: false, db_name: null, db_id: null, gifUrl: null };
  });
}

async function downloadGifs(results) {
  const gifDir = CONFIG.outputDir;
  const categories = ['lower-body', 'push', 'pull', 'core', 'flexibility'];

  for (const cat of categories) {
    fs.mkdirSync(path.join(gifDir, cat), { recursive: true });
  }

  let downloaded = 0;
  let skipped = 0;
  let failed = 0;

  for (const ex of results) {
    if (!ex.gifUrl) {
      skipped++;
      continue;
    }

    const dest = path.join(gifDir, ex.category, `${ex.app_id}.gif`);
    if (fs.existsSync(dest)) {
      console.log(`  [skip] ${ex.app_name} (already exists)`);
      skipped++;
      continue;
    }

    try {
      console.log(`  [download] ${ex.app_name} → ${dest}`);
      const headers =
        CONFIG.source === 'rapidapi'
          ? {
              'X-RapidAPI-Key': CONFIG.rapidApiKey,
              'X-RapidAPI-Host': 'exercisedb.p.rapidapi.com',
            }
          : {};
      await downloadFile(ex.gifUrl, dest, headers);
      downloaded++;
      await new Promise((r) => setTimeout(r, 100));
    } catch (e) {
      console.error(`  [FAIL] ${ex.app_name}: ${e.message}`);
      failed++;
    }
  }

  return { downloaded, skipped, failed };
}

async function main() {
  const mapping = JSON.parse(fs.readFileSync(CONFIG.mappingFile, 'utf8'));
  const exercises = mapping.exercises;
  console.log(`\nLoaded ${exercises.length} exercises from mapping file`);
  console.log(`Source: ${CONFIG.source}\n`);

  let results;
  switch (CONFIG.source) {
    case 'v1':
      results = await fetchFromV1(exercises);
      break;
    case 'rapidapi':
      results = await fetchFromRapidAPI(exercises);
      break;
    case 'free':
      results = await fetchFromFreeDB(exercises);
      break;
    default:
      throw new Error(`Unknown source: ${CONFIG.source}`);
  }

  const matched = results.filter((r) => r.matched);
  const unmatched = results.filter((r) => !r.matched);

  console.log(`\n══════════════════════════════════════`);
  console.log(`MATCH RESULTS: ${matched.length}/${exercises.length} found`);
  console.log(`══════════════════════════════════════\n`);

  if (unmatched.length > 0) {
    console.log(`UNMATCHED (${unmatched.length}):`);
    for (const ex of unmatched) {
      console.log(`  ✗ ${ex.app_name} (searched: ${ex.exercisedb_name})`);
    }
    console.log();
  }

  console.log(`MATCHED (${matched.length}):`);
  for (const ex of matched) {
    const hasGif = ex.gifUrl ? '🎬' : '📷';
    console.log(`  ✓ ${ex.app_name} → ${ex.db_name} ${hasGif}`);
  }

  const withGifs = results.filter((r) => r.gifUrl);
  if (withGifs.length > 0) {
    console.log(`\nDownloading ${withGifs.length} GIFs...\n`);
    const stats = await downloadGifs(results);
    console.log(`\nDone! Downloaded: ${stats.downloaded}, Skipped: ${stats.skipped}, Failed: ${stats.failed}`);
  } else {
    console.log('\nNo GIF URLs found. Try using source "v1" or "rapidapi" for animated GIFs.');
  }

  fs.mkdirSync(CONFIG.outputDir, { recursive: true });
  const reportPath = path.join(CONFIG.outputDir, 'match-report.json');
  fs.writeFileSync(reportPath, JSON.stringify(results, null, 2));
  console.log(`\nFull report saved to: ${reportPath}`);

  const catalog = results.map((r) => ({
    id: r.app_id,
    name: r.app_name,
    category: r.category,
    matched: r.matched,
    dbName: r.db_name,
    exerciseDbId: r.db_id,
    gifFile: r.gifUrl ? `${r.app_id}.gif` : null,
    equipment: r.equipment,
    targetMuscle: r.target_muscle,
  }));

  const swiftPath = path.join(CONFIG.outputDir, 'exercise-catalog.json');
  fs.writeFileSync(swiftPath, JSON.stringify(catalog, null, 2));
  console.log(`Legacy catalog (${catalog.length} rows) saved to: ${swiftPath}`);

  const dbCatalog = {
    version: 1,
    exercises: results.map((r) => ({
      id: r.app_id,
      name: r.app_name,
      matched: r.matched,
      exerciseDbId: r.db_id,
      exerciseDbName: r.db_name,
      gifUrl: r.gifUrl,
      targetMuscles: r.targetMuscles ?? [],
      bodyParts: r.bodyParts ?? [],
      equipments: r.equipments ?? [],
      secondaryMuscles: r.secondaryMuscles ?? [],
      instructions: r.instructions ?? [],
    })),
  };

  const dbCatalogPath = path.join(__dirname, '..', '..', 'Shared', 'Resources', 'exercise-db-catalog.json');
  fs.mkdirSync(path.dirname(dbCatalogPath), { recursive: true });
  fs.writeFileSync(dbCatalogPath, JSON.stringify(dbCatalog, null, 2));
  console.log(`Bundle catalog for Swift saved to: ${dbCatalogPath}`);
}

main().catch((e) => {
  console.error('Fatal error:', e);
  process.exit(1);
});
