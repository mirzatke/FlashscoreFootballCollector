# v43 Archive Compatibility — Hotfix 2

- Removed all bundled DCU files. Delphi must compile the updated PAS source instead of using stale DCUs.
- In `cmArchive2022`, phase flow skips all seven Player Stats pages after lineups.
- Fixed lineups coverage: a collected lineups object is now Coverage=1.
- Coverage report identity now uses the extracted Flashscore `match_id` and canonical `source_url`.
- Replaced the invalid Argentina–Netherlands smoke item with canonical Argentina–Mexico and added known `mid` values.
- Removed archive processed-state from the package so the five-match test starts clean.

Run **Project > Build** (not only Run) before executing `run_archive_2022_test.bat`.
