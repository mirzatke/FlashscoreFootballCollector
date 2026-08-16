# v45.1 Batch Continuation Fix

## Fixed
- Premier League full-season collection stopped after one successfully saved match.
- `FinishSuccess` treated Premier League as batch mode but called an archive-only continuation method.
- Replaced `ContinueArchiveBatch` with generic `ContinueBatch`.
- The next unprocessed queue item is now started for both World Cup archive and Premier League full-season modes.
- Archive-only batch report behavior remains limited to `cmArchive2022`.

## Build status
Not compiled in this environment. Compile in Delphi and provide the build log if errors occur.
