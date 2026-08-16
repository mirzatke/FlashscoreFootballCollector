# v39 Runtime Fix

Schema remains `3.19`.

## Changed files

- `Source/Collector.StructuredEvents.pas`
- `Source/Collector.Scripts.pas`

## Fixes

1. Loop control variables used by nested procedures are now declared locally.
   This removes Delphi `E1019: For loop control variable must be simple local variable`.
2. VAR detection now matches the `VAR` token or `video assistant referee`.
   Player names such as `Alvarado` and `Kovar` no longer cause false
   `is_var_decision = true` values.
3. `review_started` is detected before final VAR decisions such as `penalty`.
4. VAR review-start and final-decision events are linked by
   `related_event_minute`.
5. Overturned cards are linked to the nearest final VAR event for the same
   resolved player. A final VAR event that is already linked to a review-start
   event receives `related_overturned_card_minute`.
6. Substitutions containing text such as `after the half-time break` are no
   longer classified as period events.
7. Structured event validation now includes:
   - `unlinked_var_event_count`
   - `linked_overturned_card_count`
   - `unlinked_overturned_card_count`
   - `invalid_var_decision_flag_count`
   - `all_var_events_linked`
   - `all_overturned_cards_linked`
8. `all_structured_events_resolved` now requires all VAR events and overturned
   cards to be linked and requires zero invalid VAR-decision flags.

## Expected regression results

- Mexico vs South Africa: Jimenez goal must have
  `is_var_decision = false`.
- South Korea vs Czech Republic: Hwang In-Beom goal must have
  `is_var_decision = false`.
- Qatar vs Switzerland: minute 14 must be `review_started`, minute 16 must be
  `penalty`, and the two events must link to each other.
- USA vs Paraguay: minute 52 VAR event must link to the overturned card at
  minute 50; the minute 46 substitution must not appear in `events.periods`.

Compilation has not been claimed or simulated. Compile this package with the
real Delphi compiler and then rerun the five runtime fixtures.
