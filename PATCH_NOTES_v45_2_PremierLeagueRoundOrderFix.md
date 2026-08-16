# v45.2 Premier League Round Order Fix

## Fixed

- Premier League 2025/2026 discovery no longer saves every partial
  newest-first Flashscore snapshot while `Show more` is still loading older
  rounds.
- The collector now waits for the complete rendered results list and builds
  the queue once in chronological order, from Round 1 onward.
- Fixed the remaining archive-only guard in `ContinueBatch`; Premier League
  full-season collection now continues with the next unprocessed match after a
  successful save.
- Added a 380-match completeness guard for Premier League 2025/2026. An
  incomplete discovery is reported and collection does not start from a later
  round by mistake.
- Premier League batch completion now reports processed queue progress instead
  of archive-only saved/partial/failed counters.

## Root cause

The first rendered snapshot contained only the latest part of the season. It
was reversed and saved immediately. Each subsequent `Show more` snapshot added
only the newly found older matches to the end of that queue. The queue therefore
contained all 380 matches but its first item belonged to Round 28 rather than
Round 1.
