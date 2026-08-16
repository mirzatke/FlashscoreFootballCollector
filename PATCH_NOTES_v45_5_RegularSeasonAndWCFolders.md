# v45.5 Regular Season and World Cup Folder Isolation

## League discovery

- All domestic league profiles are marked as regular-season-only.
- The discovery script reads the nearest Flashscore stage/round heading.
- Matches belonging to an appended `Final` stage are ignored.
- For full-season collection, the expected league match count remains a second
  guard against unlabeled relegation/play-off matches.
- Bundesliga and Ligue 1 therefore retain exactly 306 regular-season matches.

## World Cup output folders

- World Cup 2022: `Data\Matches\WC\WC_2022`
- World Cup 2026: `Data\Matches\WC\WC_2026`
- Legacy outputs are migrated without overwriting an existing destination file.

## WebView2 data

`Data\WebView2` stores the WebView2 browser profile, cookies, cache and related
runtime state. `WebView2Loader.dll` beside the executable is a separate native
loader dependency. The profile folder is not source data and does not need to
be distributed; when deleted while the collector is closed, it is recreated.

## Verification status

Source structure and ZIP integrity were checked in the Codex environment.
Delphi 12.3 and the Windows WebView2 runtime are not available there, so an
actual compile and live Flashscore DOM run still require Windows verification.
