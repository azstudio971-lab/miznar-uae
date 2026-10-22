# WudCar 1.6.0 (18) — Audio-only entitlement validation

Based on owner-tested build 17, branch head `6ca24bc877495dbaed55ff2aa833e687fa4e058f`.

App Review rejected 1.4.2 (14) under 2.5.1 and specifically requested removing `com.apple.developer.carplay-video` while retaining `com.apple.developer.carplay-audio`. The CarPlay Entitlements email of October 14, case 22772031, also states that Audio supports combined audio/video services and the two entitlements must not be combined.

Scope: remove Video from the signed app, keep Audio, increment the build to at least 18, and update both existing signed build checks. The signed archive gate requires Audio=true, rejects any Video key (even false), and confirms the provisioning profile authorizes Audio. An existing provisioning profile may authorize a superset; this does not grant Video to the signed app. Account capabilities, certificates, Bundle ID `com.azstudio.wudcar`, UI, WebView, browser behavior, players and data remain unchanged.

Local validation passed: source plist Audio-only; one valid and five invalid signed/profile entitlement scenarios; YAML parsing and both workflow gates; existing logo integrity. Native tests, signed archive validation and Apple processing must be verified in Codemagic/TestFlight before delivery.

Authorization: internal TestFlight upload for owner testing only. No App Store resubmission, release metadata edit, production merge, or message to Apple. Keep marketing version 1.6.0. Owner must test physical CarPlay after this entitlement change; the simulator cannot establish vehicle behavior.

## Signed build and delivery — 2026-10-23

- Source: `2b96c6a91ffa134a29c9e81a6998acc09f57b2f8` on `develop/wudcar-build-18`.
- Codemagic `6ada77468a524d15d6a62bc3` finished successfully. Eight native tests passed, zero failures, in 300.902s. Live YouTube phone-before-car-controller probe passed in 264.001s; both targets desktop=true/mobile=false, CSS width 1280, pageZoom=1.0, stable channel/back navigation. These are simulator results, not physical CarPlay certification.
- Actual exported signed IPA check passed: Audio=true; Video key absent; provisioning profile authorizes Audio. Actual version 1.6.0, build 18; existing CarPlay/external-display scene roles preserved.
- Apple upload succeeded with no errors, delivery UUID `27b03531-2aec-4868-973b-ab66bac2f742`, October 23 at 01:01 UAE time. Processing completed; WudCar Internal has 18 builds and one tester. Build 1.6.0 (18) is Testing with 90-day expiry.
- TestFlight screenshot: `verification/18/testflight-1.6.0-18-testing.png`.
- No change description was added, no external beta review or App Store submission was initiated, no production branch or review metadata was changed, and no reply was sent to Apple.
- Independent GitHub run `39852289811` initially passed 12 of 13 tests; the local fixture document-readiness wait in `testDesktopViewportZoomNavigationAndResizeOnPhoneThenCar` exceeded its timeout on that runner. The same test passed on Codemagic, and live YouTube passed on both runners. Failed GitHub jobs were retried without code changes; retry outcome is recorded below when available. No application code was changed to address a test-runner wait.

Physical acceptance remains pending owner testing: install build 18, confirm CarPlay app visibility, browser controls and desktop layout, parked video/audio playback, exit and reopen. App Store resubmission requires subsequent owner approval.
