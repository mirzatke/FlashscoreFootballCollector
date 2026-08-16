# v45.7 WebView2 Zoom 60%

- The embedded `TEdgeBrowser` now uses `ZoomFactor = 0.60`.
- Zoom is applied in `EdgeCreateWebViewCompleted`, after successful WebView2
  creation and before discovery or collection starts.
- The setting applies to interactive, single-match, full-season and archive
  modes because all modes reuse the same WebView2 instance.
- Existing v45.6 profile-specific logging and all earlier collector behaviour
  are preserved.

Not compiled in this environment. Compile with Delphi 12.3 and verify that the
first discovery page and subsequent match tabs remain at 60% zoom.
