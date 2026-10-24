# WudCar 1.4.2 player — programming checkpoint

Paused at the owner's explicit request on 2026-10-24: finish basic programming, then stop before Codemagic build/TestFlight work so the owner can switch models. Do not start a build or publish until the owner gives the next instruction.

## Source and constraints
- Repository: azstudio971-lab/miznar-uae
- Branch: release/wudcar-1.4.2-player
- Exact baseline: 6ca24bc877495dbaed55ff2aa833e687fa4e058f (1.6.0 build 17).
- Target: 1.4.2, source build 15; final build selected by the requested ASC version-specific lookup.
- Bundle: com.azstudio.wudcar (confirmed in baseline, not com.azpixel.wudcar from older conversations).
- All protected files, Info.plist and entitlements remain byte-identical to baseline. Settings.swift changes only the default driving lock false → true. The SettingsView AppStorage default also matches true.
- No main merge, App Store review submission, What to Test or new permission/extension/dependency.
- SubscriptionStore and StoreKit product configuration remain unchanged.

## Implemented source
- New phone and CarPlay tab orders; settings moved beneath CarPlay Home; mouse and Web Player accessible from phone settings.
- Compact green/gray connection status and updated visible player identity.
- PHPicker video import, document/audio/multiple-file/folder import, app-private file copies, AVAsset duration/type/thumbnail loading, import results.
- Local media library, favorites, playlists, rename/delete/reorder, resume positions, recently added and channel sources.
- Channel context menus add M3U/Xtream channels to the library and mixed playlists. M3U favorite toggles synchronize newly changed favorites. Library channels also expose existing sources directly. Source removal cleans its library references.
- CarPlay library uses existing playback configuration and AVPlayer, observes library/source changes, and refreshes an open mixed playlist.
- Player preferences: subtitle selection/style, external local SRT/VTT captions, audio preference/menu, display gravity/rotation, skip/remote commands, resume/queue, phone rate, sleep timer, PiP, forward buffer, connection timeout and reset.
- Eight bilingual legal/help documents, 13 FAQ entries, same player documents in web/src/policies.js. Support: az.studio971@gmail.com.
- New wudcar-142-player workflow, separate from unchanged existing workflows. It runs full WdCarTests plus existing browser gate and exports attachments/entitlements.

## Verified here
- python3 scripts/verify_142_baseline.py — PASS.
- python3 scripts/verify_142_structure.py — PASS (source invariants only).
- Original Codemagic workflow mappings compare equal to baseline — PASS.
- node --check web/src/policies.js — PASS.
- Eight bilingual documents and 13 FAQ entries — PASS.
- git diff --check — PASS.
- No Xcode/Swift toolchain is installed in this Linux workspace. No native compile, simulator test, signing or upload result exists for this release. Do not describe source checks as runtime tests.

## Next authorized phase, only after owner resumes
1. Run native Xcode build, correct compiler/runtime failures and run all tests (Release160Tests, Release17Tests and new Release142PlayerTests). Existing tests have not been changed.
2. Complete deeper verification: actual thumbnail import, subtitle style and media selection, live channels, CarPlay template limits/depth and source favorites across upgrades. CarPlay root now pages in place within the total item budget. Verify large-library navigation and add paging to oversized individual mixed-playlist detail screens if needed before claiming all such detail items are reachable.
3. Check phone/CarPlay layouts, RTL, PiP, rotation and external playback. Review queue/resume behavior under interrupted imports and deletion. Test actual car only by owner.
4. The included screenshot test creates simulator-hosted attachments for Home, empty Library, IPTV and player settings at requested resolutions. It is not a finished App Store screenshot set. Populate legal sample media and capture playback/CarPlay plus visual QA; complete docs/appstore/1.4.2 metadata, review notes and reply draft. Do not submit these to App Store.
5. Baseline workflow actually has submit_to_testflight:false and no beta_groups, unlike the task's assumption. New workflow has true and WudCar Internal, no beta review text, submit_to_app_store:false. Verify Codemagic internal-group semantics before starting it.
6. Stop and report the full Apple error if version/build is rejected. Do not change version scheme without owner direction.
7. Save real signed entitlements from build artifact into docs/verification/142/signed-entitlements.txt. Do not fabricate this file now.
8. Verify actual WudCar Internal Testing state and final build number in App Store Connect, then deliver branch/commit/build links, protected diff, entitlements, changed-file report and remaining owner tests.

## Access / continuation
- Local checkout during this turn: /workspace/scratch/3b9cece6f45e/wudcar (may be ephemeral; GitHub is authoritative).
- git clone/read succeeds but shell git push lacks credentials. Use connected GitHub create_tree/create_commit/update_ref with expected SHA. Commit local changes as a checkpoint too; remote SHA differs because commits are created through the connector.
- Browser skill c8/control-browser was read. Connected Chrome works; Codemagic session authenticated. App ID 6ad1db1b951fcdf1e4f45860. ASC app ID 6823772404.
- Codemagic build modal was cancelled following the owner's pause instruction; no new Codemagic build started.

## Continuation 2026-10-24
Owner resumed full implementation/build/internal upload via attached specification, then explicitly required the subscription to remain exactly as baseline 1.6.0 (17), covering all features. SubscriptionView is restored byte-for-byte; SubscriptionStore, SubscriptionGate and the StoreKit product fixture stay unchanged. The period-label helper used only by the legal page now lives in LegalViews.swift.

Observed pre-existing Codemagic build 6adc83ca4a72334e32e4ad0b fetched sources in six seconds and compiled Debug successfully. Release160Tests (5) and Release17Tests (3) passed. SubscriptionTests hit SKInternalErrorDomain Code=3 on Xcode 26.6/iOS 26.5 and hung after the fixture price assertion. Cancelled the stalled run before signing/upload. Apple DTS acknowledges matching StoreKit CI failures: https://developer.apple.com/forums/thread/826971 . New workflow pins Xcode 27.1 / iOS 27.0, restores ALL tests (including CarInterfaceTests), and bounds test execution; no subscription app code or product price was changed. This is an attempted CI remedy, not yet a verified success. Other workflows remain unchanged.
