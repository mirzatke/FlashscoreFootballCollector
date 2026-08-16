# v43 Archive Compatibility — Hotfix 3

## Added
- New collection phase: `cpStatisticsExtraTime`.
- Flashscore URL: `/summary/stats/extra-time/`.
- Extracted section: `statistics_extra_time`.
- Period key in `statistics_by_period`: `extra_time`.
- Coverage key: `statistics_extra_time`.

## Flow
- After `statistics_second_half`, collector checks the match status collected from the overall page.
- If status contains `EXTRA TIME`, it collects the extra-time statistics page.
- Otherwise it records `statistics_extra_time` as `coverage=0`, `status=not_available`, then continues to lineups.
- Missing or failed extra-time pages do not stop an Archive 2022 batch.

## Compatibility
- Main output schema remains `3.19`.
- Existing `statistics` continues to contain overall statistics.
- Extra-time rows are added only under `statistics_by_period.extra_time`.
- No compiled `.dcu` files are included. Perform Project > Build.
