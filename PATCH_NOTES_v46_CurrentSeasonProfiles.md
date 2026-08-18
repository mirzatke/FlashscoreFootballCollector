# v46 — Current/Archive Season Profiles

## What changed

- Added `TSeasonKind = (skCurrent, skArchive)`.
- Added `TSeasonProfile` with explicit season metadata:
  - display caption
  - stable season key
  - season kind
  - archive URL slug
  - player-stats support flag
- Added 2026/2027 as the current season for all five supported European leagues.
- Current-season URLs no longer contain a season suffix.
- Archive-season URLs continue to contain their explicit season suffix.
- URL generation is centralized in `Collector.Profiles.pas`.
- `MainFormUnit` continues to consume `TCompetitionProfile` and does not construct Flashscore league URLs itself.

## Current-season URL form

- England: `https://www.flashscore.com/football/england/premier-league/results/`
- Spain: `https://www.flashscore.com/football/spain/laliga/results/`
- Germany: `https://www.flashscore.com/football/germany/bundesliga/results/`
- Italy: `https://www.flashscore.com/football/italy/serie-a/results/`
- France: `https://www.flashscore.com/football/france/ligue-1/results/`

Fixtures use the same base paths with `/fixtures/`.

## Archive URL form

Example for LaLiga 2025/2026:

`https://www.flashscore.com/football/spain/laliga-2025-2026/results/`

## Important

This change is based on the repository's current v45.9 `main` branch so the Discovery Stability Fix is preserved.

No Delphi compiler is available in this environment. The source change has been reviewed structurally, but a real Delphi build log is still required before marking v46 compile-verified.
