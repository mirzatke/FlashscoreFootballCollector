# v45.8 Dynamic Optional Player Stats

- Player Stats availability is now evaluated per match rather than only by
  competition/season profile.
- A missing or empty Player Stats page is recorded as `coverage=0` and
  `status=not_available` with a null coverage error.
- If the first (Top Stats) page is unavailable, the collector marks all seven
  Player Stats categories unavailable and continues directly to Commentary.
- If a later Player Stats category is unavailable, only that category is
  skipped and collection continues with the next category.
- Missing Player Stats no longer fail the match, mark the match partial, or stop
  a league batch, including 2024/2025 matches before Player Stats became
  available on Flashscore.
- Real failures in required sections (match/period statistics, lineups and
  commentary) retain the existing failure behavior.
