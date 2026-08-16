# v45 Multi-Competition UI

## New GUI
- Competition selector: FIFA World Cup / English Premier League.
- Season selector: World Cup 2026 or 2022; Premier League 2025/2026.
- Collection mode selector: full season, resume, discovery only, single match.
- Dedicated Discover, Start, Safe Stop, Next Match, Open Output and View JSON actions.
- Progress bar, status area, browser workspace and structured log area.

## Premier League 2025/2026
- Results discovery URL is isolated from World Cup data.
- Output: Data\\Matches\\PremierLeague\\2025_2026
- Queue: Data\\premier_league_2025_2026_matches.json
- Processed state: Data\\processed_matches_premier_league_2025_2026.json
- Same Stats, halves, Lineups, Player Stats and Commentary phases are reused.

## Command line retained
- -collect-one
- -archive-2022
- -premier-league-2025-2026

## Compatibility
- Existing World Cup collection flow and schema 3.19 remain in place.
- This source package has not been compiled in Delphi in this environment.
