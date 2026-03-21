#!/usr/bin/env node
/**
 * Reads exercise-gifs/match-report.json and fetches full ExerciseDB records by id
 * (instructions, muscles, etc.), then writes Shared/Resources/exercise-db-catalog.json.
 *
 *   node enrich-exercise-db-catalog.js
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

const ROOT = path.join(__dirname, '..', '..');
const REPORT = path.join(__dirname, 'exercise-gifs', 'match-report.json');
const OUT = path.join(ROOT, 'Shared', 'Resources', 'exercise-db-catalog.json');

const DEFAULT_HEADERS = {
  Accept: 'application/json',
  'User-Agent':
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
};

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function fetchJSON(url, attempt = 0) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    https
      .get(
        { hostname: u.hostname, path: u.pathname + u.search, headers: DEFAULT_HEADERS },
        (res) => {
          let data = '';
          res.on('data', (c) => (data += c));
          res.on('end', async () => {
            if (res.statusCode === 429 && attempt < 8) {
              const delayMs = Math.min(30_000, 2000 * 2 ** attempt);
              console.warn(`429, retry in ${delayMs / 1000}s`);
              await sleep(delayMs);
              try {
                resolve(await fetchJSON(url, attempt + 1));
              } catch (e) {
                reject(e);
              }
              return;
            }
            if (res.statusCode !== 200) {
              reject(new Error(`HTTP ${res.statusCode}`));
              return;
            }
            try {
              resolve(JSON.parse(data));
            } catch (e) {
              reject(e);
            }
          });
        }
      )
      .on('error', reject);
  });
}

async function fetchExerciseDetail(id) {
  const url = `https://www.exercisedb.dev/api/v1/exercises/${id}`;
  const res = await fetchJSON(url);
  return res.data ?? null;
}

async function main() {
  const report = JSON.parse(fs.readFileSync(REPORT, 'utf8'));
  const detailCache = new Map();

  for (const row of report) {
    if (!row.db_id || detailCache.has(row.db_id)) continue;
    try {
      console.log(`Fetch ${row.app_name} (${row.db_id})`);
      const d = await fetchExerciseDetail(row.db_id);
      detailCache.set(row.db_id, d);
      await sleep(250);
    } catch (e) {
      console.error(`  fail ${row.db_id}: ${e.message}`);
    }
  }

  const exercises = report.map((row) => {
    const d = row.db_id ? detailCache.get(row.db_id) : null;
    const src = d || row;
    return {
      id: row.app_id,
      name: row.app_name,
      matched: !!row.matched && !!d,
      exerciseDbId: row.db_id,
      exerciseDbName: d?.name ?? row.db_name ?? null,
      gifUrl: d?.gifUrl ?? row.gifUrl ?? null,
      targetMuscles: d?.targetMuscles ?? row.targetMuscles ?? [],
      bodyParts: d?.bodyParts ?? row.bodyParts ?? [],
      equipments: d?.equipments ?? row.equipments ?? [],
      secondaryMuscles: d?.secondaryMuscles ?? row.secondaryMuscles ?? [],
      instructions: d?.instructions ?? row.instructions ?? [],
    };
  });

  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, JSON.stringify({ version: 1, exercises }, null, 2));
  console.log(`Wrote ${OUT} (${exercises.length} exercises)`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
