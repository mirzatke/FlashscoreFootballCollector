# Next implementation stages

## Stage 2 — complete match tabs

Add explicit navigation and extraction for:

- Summary / incidents
- Statistics / overall
- Lineups
- Player ratings
- Missing players / injuries

Each tab should be extracted into a separate object and merged before the match file is committed.

## Stage 3 — tournament discovery

Add a tournament-page parser that collects finished-match URLs from 2026-06-01 onward and writes them into `Data\match_queue.json` in chronological order.

## Stage 4 — robust retry policy

- Retry page load at most twice.
- Never mark a match processed on partial or empty statistics.
- Store failed attempts in a separate failure log.
- Use an atomic temp-file-then-rename save.

## Stage 5 — selector diagnostics

Save a compact DOM diagnostic file when required selectors are missing, so selector changes can be repaired without guessing.
