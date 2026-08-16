# v43 Hotfix 4 — Archive coverage semantics

- Expected `not_available` Player Stats categories no longer mark 2022 archive matches as partial.
- `statistics_extra_time=not_available` on normal-time matches no longer marks a match as partial.
- Required base sections (`statistics_match`, first half, second half, lineups, commentary) still mark a match partial when unavailable.
- Any section with `failed` or `empty` status still marks the match partial.
- No JSON schema changes; match output remains schema 3.19.
