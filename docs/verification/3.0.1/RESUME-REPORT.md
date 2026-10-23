# Resume checkpoint — 2026-10-23

Source under test: `f14d3265dea56641f9aa4fed67f25594c60cefec`.
The existing Codemagic build was resumed by observation, not restarted:
https://codemagic.io/app/6ad1db1b951fcdf1e4f45860/build/6adb53d84a72334e32e46243

Independent GitHub verification:
https://github.com/azstudio971-lab/miznar-uae/actions/runs/39953949991

## Confirmed results from this same run

- GitHub web job: success, including checks and UI tests.
- Native compilation: success.
- Frozen-browser gate: success. All 26 protected files match build 17 byte-for-byte, and three original browser launch/configuration methods remain verbatim. `browser-diff-stat.txt` is empty.
- Codemagic CarInterfaceTests: 21 test cases completed; 19 passed, 2 failed, containing 5 failed assertions. This is not an all-pass result.
- `testFullFrameAtAllZoomLevelsAndVideoExit`: three failed assertions. On iOS 18.5 the fixture reported content width 402 versus visual viewport 412 at 50%, then 402 versus 268 at 150%, and fullscreen x = -10.6667 versus expected 0. The browser implementation and this test are unchanged from build 17; the failure alone does not establish a new code regression or prove harmlessness.
- `testM3UParsingAndAddedShortcuts`: two failed assertions require Netflix and Prime Video. Those defaults were intentionally removed by the approved build-17 catalog. No shortcut has been restored and no test has been silently skipped.
- Native import, thumbnail/duration, playlist ordering/rename/favorites, position persistence and invalid-file rollback tests passed.
- Existing live desktop-site test passed. This does not replace physical iPhone/CarPlay acceptance or establish the outcome of the separate full YouTube navigation probe.
- New public Apple HLS playback test reported source connection timeout before ready-to-play. Successful playback has not been established by this run; the precise cause remains unconfirmed.

## Release boundary

Full-suite completion, final screenshots and signed archive are still pending at this checkpoint. Test failures block archive and publishing automatically. No new build, duplicate upload, App Store review submission, metadata upload, or production merge was initiated during resumption. No signed-entitlement contents are claimed before an actual signed IPA exists. Physical vehicle testing remains with the owner.
