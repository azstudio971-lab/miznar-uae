# WudCar 1.4.2 — actual continuation result, 2026-10-24

Status: implementation and native compilation verified; internal upload NOT completed.

## Identity and source
- Branch: https://github.com/azstudio971-lab/miznar-uae/tree/release/wudcar-1.4.2-player
- App source and workflow commit: f31a7a75c2248f0f8e9d3c1238c32624ea49c6df
- Baseline: 6ca24bc877495dbaed55ff2aa833e687fa4e058f, approved build 17.
- Latest attempted build: https://codemagic.io/app/6ad1db1b951fcdf1e4f45860/build/6adc8dba4a72334e32e4af31
- Marketing version 1.4.2; source build 15. No signed/uploaded final build number exists for this attempt.
- Bundle identifier remains com.azstudio.wudcar. No main merge.

## Latest owner requirement: subscription exactly as 1.6.0 (17)
SubscriptionView.swift, SubscriptionStore.swift and WudCar.storekit are byte-identical to baseline. No subscription product, price, period, trial, renewal, restore behavior or App Store Connect subscription setting was changed. The original SubscriptionGate is retained, and the single existing subscription covers Library, IPTV, Web Player and car tools. New PlaybackManager operations use the same shared access check. See baseline-checks.txt for SHA256 evidence.

## Actual verification
- Native Debug build on stable Xcode 27.0: PASSED.
- Release142PlayerTests: 4 passed (lock default, real WAV import/copy/duration, playlist ordering/removal/progress, native screenshots, subtitle parsing/skip). These do not prove every requested runtime player behavior.
- Release150Tests: 5 passed.
- Release160Tests: 5 passed, including live YouTube phone-before-car simulator probe.
- Release17Tests: 3 passed.
- CarInterfaceTests: FAILED, including unavailable verified StoreKit test subscription, stale default shortcut expectations for Netflix/Prime Video and viewport assertions. The files containing these implementations/tests are unchanged from baseline; this is not proof that every failure is exclusively an environment problem.
- SubscriptionTests: FAILED price assertion: SubscriptionTests.swift:28, actual 5.99 versus local fixture 24. The purchase then waited; the doomed run was cancelled to conserve minutes, so the complete suite did not finish. Neither actual store price nor local fixture was changed.
- Earlier Xcode 26.6/iOS 26.5 attempt had SKInternalErrorDomain Code=3 during StoreKit fixture setup. Xcode 27.0 did not resolve the full local StoreKit entitlement issue.
- Protected-file byte comparison: PASSED; required protected diff is empty. DrivingMonitor.swift diff is empty. Settings.swift changes only default false to true. Info.plist and entitlements are unchanged.
- Structural tab/status/picker/player wiring checks: PASSED.
- All pre-existing workflow mappings equal baseline: PASSED.
- npm test: 7 passed. npm run build and policy JavaScript syntax: PASSED.
- Playwright UI tests could not launch because the Chromium download returned invalid archives. Not a passing UI result.
- No existing native test source was edited. See changed-files.md.

## Internal-only publishing
The inherited new-workflow submit_to_testflight:true would request beta review according to Codemagic docs. It is now false, submit_to_app_store is false, and export options use testFlightInternalTestingOnly:true. No What to Test or review request was entered. The intended final action is assignment to the existing WudCar Internal group after successful upload.

App Store Connect was inspected after owner login. WudCar Internal is an existing internal group with one tester; latest visible 1.4.2 build is 14 (expired). No 1.4.2 (15) was uploaded by this continuation. Group membership for a new build is NOT verified because upload was not reached.

## Deliverable locations
- docs/appstore/1.4.2/metadata-ar.md and metadata-en.md
- docs/appstore/1.4.2/review-notes.md and reply-to-review.md — drafts only, not submitted
- docs/appstore/1.4.2/sample.m3u — official Apple Bip Bop developer test stream, manifest fetched successfully
- docs/appstore/1.4.2/screenshots/README.md — requirements; complete populated screenshot set not delivered
- Support: az.studio971@gmail.com

## Not completed / blocker
No signed IPA, signed-entitlements.txt or new internal TestFlight build exists for this attempt. Do not invent signed entitlements from the source entitlement file. Native screenshot tests generated attachments, but the complete store screenshot set, actual playing-video/CarPlay library captures and visual QA remain incomplete. Runtime checks of video thumbnails, media selection/style, PiP, rotation and large-library CarPlay interaction remain incomplete. No actual-car test was performed.

The supplied specification restricts edits to existing tests to new tab order/text effects. Resolving the remaining legacy StoreKit/viewport/catalog expectations requires clarification before broader test changes or any relaxation of release checks. No failing test was hidden, skipped or relabeled as passed.
