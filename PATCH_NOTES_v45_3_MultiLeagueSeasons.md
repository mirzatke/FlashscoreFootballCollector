# v45.3 Multi-League Seasons

## Added competition profiles

- English Premier League
- Spanish LaLiga
- German Bundesliga
- Italian Serie A
- French Ligue 1

Each league supports seasons 2025/2026, 2024/2025 and 2023/2024.
The existing FIFA World Cup 2026 and Archive 2022 profiles remain available.

## Profile isolation

Every league/season combination has its own:

- Flashscore results and fixtures URL;
- chronological queue file;
- processed-match state file;
- output directory.

This prevents two competitions or seasons from sharing continuation state.

## Discovery validation

- Premier League, LaLiga and Serie A expect 380 matches.
- Bundesliga and Ligue 1 expect 306 matches.
- A league collection is not started from an incomplete discovery snapshot.
- The v45.2 final-snapshot reversal remains active, so queues start from the
  earliest match rather than a late round initially rendered by Flashscore.
