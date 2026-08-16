# v45.9 Discovery Stability Fix

- Added `FDiscoveryOnly` to `IsBatchMode`.
- Fixed the empty-anchor path that produced `103 matches; 0 added` during
  Discover-only full-season runs.
- Added stateful waiting after Show more clicks. A temporarily hidden button
  no longer ends discovery before Flashscore appends older rounds.
- The final newest-first DOM snapshot is still reversed once into true season
  order before the queue is saved.
- Exact expected-match-count validation remains enabled, so collection will
  not start from an incomplete league season.
- All v45.8 dynamic optional Player Stats behavior is preserved.
