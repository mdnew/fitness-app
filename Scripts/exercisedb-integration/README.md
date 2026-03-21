# ExerciseDB → demo GIFs

Fetches animated GIFs from [ExerciseDB](https://www.exercisedb.dev/) v1 (free, no API key) for the 75 built-in library exercises, using fuzzy name matching.

## Run

```bash
cd Scripts/exercisedb-integration
node fetch-exercise-gifs.js
```

Outputs (under `exercise-gifs/`):

| Artifact | Purpose |
|----------|---------|
| `match-report.json` | Full match results + URLs |
| `exercise-catalog.json` | One row per app exercise; `gifFile` is `null` when there was no match or no GIF |
| `{category}/{app_id}.gif` | Bundled assets (e.g. `lower-body/goblet-squat.gif`) |

## API notes

- Base URL: **`https://www.exercisedb.dev/api/v1`** (paginated `data`, fields `exerciseId`, `name`, `gifUrl`). The host `v1.exercisedb.dev` is unreliable for scripts.
- The public API expects a **browser-like `User-Agent`**; otherwise it returns a non-JSON error payload.
- You may see **HTTP 429** while paging (15 requests × ~100 exercises). The script backs off and retries; add a longer pause between runs if needed.
- Fetches **all ~1500** exercises before matching; with the full list we typically see **~55–60 / 75** automatic matches. Tighten `exercise-mapping.json` or use RapidAPI v2 for the rest.
- Matching prefers **`exercisedb_name`** when it hits a strong score (≥800) so short alt terms like “butterfly” do not override “lever pec deck fly”.

## Xcode

1. Drag `exercise-gifs/` into the app target (or a shared target), preserving folder references if you want paths like `exercise-gifs/lower-body/foo.gif`.
2. Add `exercise-catalog.json` to the target.
3. In Swift, resolve demos by a **stable slug** (`id` in the catalog). Today `ExerciseLibraryItem` only has a random `UUID` for seeded exercises; for a durable link you can add an optional `catalogSlug: String?` on seeded items equal to `app_id`, or match on normalized `name` (more fragile).

## Alternatives

- **RapidAPI v2**: Set `source: 'rapidapi'` and `rapidApiKey` in `fetch-exercise-gifs.js` for broader coverage.
- **free-exercise-db**: Set `source: 'free'` for static JPGs only (see upstream script comments).

Unmatched exercises (stretches / niche moves) can keep your existing placeholder art until you add manual mappings in `exercise-mapping.json`.
