> Mandatory correction: see SUBSCRIPTION-CORRECTION.md. SubscriptionTests.swift has now been restored exactly to build 17; the historical skipped test result below does not validate the current source. Original SubscriptionTests success remains unverified.

# WudCar 1.4.2 — actual result as of 2026-10-24

**Not uploaded to TestFlight.** App compilation and native test assertions completed; four StoreKit-dependent tests remain unavailable. The XCTest step stalled during finalization and Codemagic build minutes are now exhausted.

## Source and identity
- Branch: https://github.com/azstudio971-lab/miznar-uae/tree/release/wudcar-1.4.2-player
- App/test source used by the final run: 039b88585eacd97b744f185a59df6a7096250a8e.
- Baseline: 6ca24bc877495dbaed55ff2aa833e687fa4e058f, build 17.
- Final run: https://codemagic.io/app/6ad1db1b951fcdf1e4f45860/build/6adc96f14a72334e32e4b150
- Target 1.4.2; source build 15. No final signed/uploaded build number was selected/completed.
- Bundle identifier remains com.azstudio.wudcar. No main merge or App Store submission.

## Subscription preserved exactly
SubscriptionView.swift, SubscriptionStore.swift and WudCar.storekit are byte-identical to build 17. No price, product ID, duration, trial, renewal, restore behavior or App Store Connect subscription setting was changed. The original SubscriptionGate is retained and one existing Premium subscription covers all features, including the new library/player. See baseline-checks.txt.

## Native results
| Suite | Passed | Unavailable / skipped | Failed |
| --- | ---: | ---: | ---: |
| CarInterfaceTests | 18 | 3 | 0 |
| Release142PlayerTests | 4 | 0 | 0 |
| Release150Tests | 5 | 0 | 0 |
| Release160Tests | 5 | 0 | 0 |
| Release17Tests | 3 | 0 | 0 |
| SubscriptionTests | 0 | 1 | 0 |
| Total | 35 | 4 | 0 |

The unavailable cases require a local StoreKit test purchase: repeated playback stop, car-player routing, welcome/paid-TV navigation, and the complete subscription lifecycle. The fixture expects numeric price 24; StoreKit returned 5.99 despite the explicit local test plan. No real-store purchase was attempted. These are not passed subscription tests and do not prove a changed real price or broken production subscription. Exact root cause of local StoreKit activation remains unconfirmed; Apple DTS documents related CLI/simulator problems at https://developer.apple.com/forums/thread/826971 .

Native Debug compilation passed. The new tests covered default driving lock, WAV import/copy/duration, playlist order/removal/progress, subtitle parsing/skip and native screenshot attachments. Release160 included the live YouTube phone-before-car simulator probe. Console evidence: native-results-039b885.txt. All test suites remained scheduled; only the four environment-dependent cases explicitly reported skips. Owner authorized the legacy-test corrections; see TEST-REPAIRS.md.

Other verification: protected baseline/Info.plist/entitlements checks passed; DrivingMonitor.swift diff is empty; Settings.swift changes only default false to true. Original workflows remain identical. Structural checks and JavaScript policy syntax passed. npm test: 7 passed; npm run build passed. Playwright UI tests could not launch because the browser download returned invalid archives.

## Runner finalization and capacity blocker
All native assertions ended at 11:39:08 UTC. Xcode did not return from the test step afterward; the stalled run was cancelled at 16m30s. During cancellation it emitted ** TEST SUCCEEDED ** and the existing browser gate reported success; screenshot export/profile preparation briefly ran, but signing/IPA/upload did not complete.

The next workflow removes launchctl/tee and uses file-backed log relay with a 12-minute process timeout, preserving xcodebuild's real exit status. Local smoke checks verified propagation of exit codes 0 and 65. It never approves a release based solely on a console marker. This follow-up runner has not been validated on the Mac build machine; the exact hang cause remains unconfirmed.

Billing now shows **510 / 500 free macOS minutes**, with Start new build disabled. No paid plan, payment or billing setting was changed. Additional build capacity is required to complete signing and internal upload.

## Publishing and group
submit_to_testflight and submit_to_app_store are false; export is testFlightInternalTestingOnly:true. No What to Test, beta review or App Store review request was entered. App Store Connect was inspected after owner login: WudCar Internal exists with one tester. No new build was uploaded by this continuation, so new-build membership cannot be confirmed.

## Deliverables and limits
- Store metadata: docs/appstore/1.4.2/metadata-ar.md and metadata-en.md.
- Drafts only: review-notes.md and reply-to-review.md in the same directory; not submitted.
- sample.m3u uses Apple's official Bip Bop developer test stream; its manifest was fetched successfully.
- Support: az.studio971@gmail.com.
- Changed files and purposes: changed-files.md; test-repair details: TEST-REPAIRS.md.
- No signed IPA or signed-entitlements.txt exists for this attempt. Source entitlements are not substituted for signed evidence.
- Native test attachments were generated, but the complete populated store screenshot set (including playing video and actual CarPlay library) has not been retrieved/delivered. Runtime checks of video thumbnails, media track/style selection, PiP, rotation and large-library CarPlay interaction remain incomplete.
- No actual-car test was performed. The owner will test the vehicle after internal upload.
