# WudCar — Build 17 pending feedback

Recorded 2026-10-21 (Asia/Dubai), after owner testing of TestFlight 1.6.0 (16).

## Owner feedback

The owner installed build 16 and reports that everything in the browser works well. This is user-reported success, not an independently observed end-to-end test of every physical input/device acceptance criterion.

## Required next-build fix — pending

The top browser toolbar's internal icons are still too large and extend outside the toolbar frame, as shown in the supplied CarPlay photo `unnamed (1)(4).jpg` (reviewed).

For Build 17:
- Reduce the visible icon sizes and align them within the compact toolbar, particularly Home, Back, tabs and toolbar controls.
- Check intrinsic image sizing, button content/insets and constraints across supported screen dimensions; keep appropriate usable hit regions separate from visible symbol dimensions.
- Preserve all toolbar actions, direct ellipsis-to-toolbar activation, automatic hiding, desktop viewport and default 100% zoom.
- Verify visually that no icon overflows or is clipped on the phone and CarPlay; retain the current shortcuts design.

Status: recorded for the next update; no implementation, build or upload requested in this feedback message. Do not change the marketing version solely because the requested next build is 17; verify build-number availability before uploading. No production approval is implied.


## Implementation update — 2026-10-22

Toolbar overflow fix implemented in build 17 alongside the subsequently requested entertainment redesign/catalog. Signed Codemagic verification passed all 8 selected tests; Apple upload completed. Original feedback above is retained as history. Final availability and complete verification results are recorded in WUDCAR-BUILD-17-STATUS.md.
