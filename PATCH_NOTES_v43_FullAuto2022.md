# v43 Archive 2022 Full Auto

- `-archive-2022` no longer depends on a manually prepared five-match queue.
- Opens `https://www.flashscore.com/football/world/world-championship-2022/results/`.
- Clicks Flashscore `Show more` repeatedly until the complete result list is rendered.
- Extracts match IDs and canonical match URLs from the rendered DOM.
- Reverses Flashscore newest-first order into chronological order.
- Saves the discovered queue to `Data\archive_2022_matches.json`.
- Expects 64 tournament matches and writes a warning if a different count is discovered.
- Starts collection from the earliest unprocessed match and continues through the final.
- Existing archive fault tolerance, coverage reports, extra-time statistics, and Player Stats skip remain active.
