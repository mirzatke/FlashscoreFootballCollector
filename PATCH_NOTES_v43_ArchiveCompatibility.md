# v43 Archive Compatibility

## Added
- `-archive-2022` collector mode.
- Independent queue: `Data\archive_2022_test_batch.json`.
- Five-match 2022 smoke batch.
- Section-level fault tolerance for navigation, JavaScript, malformed extraction results, and timeouts.
- Per-match sidecar coverage reports under `Data\Coverage\Archive2022`.
- Batch coverage summary: `archive_2022_batch.coverage.json`.
- Missing Player Stats tabs are recorded as `coverage=0`, `status=not_available`.
- Archive outputs are isolated under `Data\Matches\Archive2022`.
- Archive processed state is isolated in `Data\processed_matches_archive_2022.json`.

## Compatibility
- Main match JSON remains `schema_version: 3.19`.
- Coverage metadata is not injected into the main JSON; it is written to sidecar files.
- Interactive and `-collect-one` behavior retains strict section validation.

## Run
```bat
run_archive_2022_test.bat
```

## Important
The package was source-reviewed and patched in this environment, but it was not compiled with Delphi. Compile it locally and provide the compiler/build log plus the five JSON and coverage outputs for runtime validation.

## Hotfix 1 — Skip unavailable 2022 Player Stats

In `cmArchive2022`, after lineups the collector no longer navigates to any
`/summary/player-stats/.../` URL. All seven player-stat categories are marked
`coverage=0`, `status=not_available`, and collection continues directly with
commentary. Interactive and `-collect-one` behavior is unchanged.
