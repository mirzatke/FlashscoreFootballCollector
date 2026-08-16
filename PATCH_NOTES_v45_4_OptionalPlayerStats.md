# v45.4 Optional Player Stats

- Keeps all 2023/2024 league profiles available.
- Marks Player Stats as unsupported for 2023/2024 league profiles and FIFA
  World Cup 2022.
- Skips all seven Player Stats navigations for profiles where the source does
  not provide those pages.
- Records every skipped Player Stats category as `coverage=0` and
  `status=not_available`; these values are not treated as numeric zero stats.
- Adds `player_stats_availability` to every saved match JSON.
- Adds the complete per-section `collection_coverage` object to every saved
  match JSON, not only to Archive 2022 coverage reports.
- Player Stats enrichment runs only when all seven categories were collected.
- Expected missing Player Stats do not make the match partial and do not stop
  full-season batch continuation.

Delphi compilation and Flashscore runtime navigation must be verified on a
machine with Delphi 12.3 and WebView2.
