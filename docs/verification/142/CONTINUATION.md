# Continuation evidence — 2026-10-24

## Subscription requirement (latest owner instruction)
SubscriptionView.swift, SubscriptionStore.swift and WudCar.storekit are byte-identical to baseline 6ca24bc. No App Store Connect subscription or pricing action was performed. The original SubscriptionGate is used for LibraryView, XtreamHomeView and car tools; PlaybackManager checks the same shared hasAccess. Premium covers the new library and player, without another product or paywall.

## Verified locally
- Protected baseline/Info.plist/entitlements/default-lock check: PASS.
- Structural tab/status/picker/preferences checks: PASS.
- Original workflow mappings: equal to baseline.
- JavaScript policy syntax: PASS.
- npm test: 7 passed, 0 failed.
- npm run build: PASS.
- Playwright UI suite: could not start Chromium; the browser download repeatedly returned an invalid archive. This is an environment failure, not a passed UI test.
- Official Apple Bip Bop test manifest fetched successfully, with audio/subtitle renditions.

## Remote observations
- Existing build 6adc83ca4a72334e32e4ad0b: native Debug compiled; Release160Tests 5/5 and Release17Tests 3/3 passed. Then StoreKit fixture setup failed with SKInternalErrorDomain Code=3, followed by product price mismatch (5.99 vs fixture 24) and a stalled purchase. It was cancelled before signing or upload.
- Current Codemagic Xcode 26.6 image uses iOS 26.5. Apple DTS thread https://developer.apple.com/forums/thread/826971 documents matching simulator failures. New workflow pins stable Xcode 27.0 and explicitly selects iOS 27.0; all native tests are restored, with execution limits. This remedy still requires an actual passing run. No subscription code or prices were changed to mask the test error.
- App Store Connect login completed by owner. WudCar Internal is an existing internal group with one tester. Version 1.4.2 latest visible build is 14 (expired); workflow queries ASC again and chooses at least 15. No metadata or review submission was made.
- Codemagic Billing showed 468/500 free macOS minutes used (32 left) at inspection. No paid plan or purchase was started.

## New source corrections
- CarPlay library detail pages now paginate instead of truncating beyond maximumItemCount. Channel/category/source lists paginate across the total template item budget. Pushes cannot exceed five templates.
- Continue watching excludes nearly completed on-demand media while retaining live channels.
- Restored original subscription screen and moved legal-only period formatting to LegalViews.swift.

## Still required before a complete handover
A full successful native test run, signed IPA, extracted signed entitlements, upload/processing and actual WudCar Internal membership must be verified. The complete populated native screenshot set (including actual CarPlay library and playing video) is not available yet. Existing screenshot attachments are only initial test captures. No real-car test has been performed.

## Internal-only publishing correction
Codemagic documentation identifies submit_to_testflight:true as submission to beta review. The inherited new-workflow setting was therefore corrected to false, beta_groups automation removed, and testFlightInternalTestingOnly:true added to export options. submit_to_app_store remains false. Upload is followed by explicit assignment to the existing internal group in App Store Connect. No review or What to Test is sent. Source: https://docs.codemagic.io/yaml-publishing/app-store-connect/ .

Build 6adc8cd94a72334e32e4af03 confirmed native Debug compilation success on Xcode 27.1. It was cancelled before publishing to apply the internal-only correction; tests had not completed. Stable Xcode 27.0 is selected for the upload attempt instead of the 27.1 RC image.

Latest outcome: see RESULT.md. Native build and 17 release tests passed, but legacy CarInterfaceTests and SubscriptionTests failed; no upload was performed. The full test attempt was cancelled after the subscription fixture mismatch and waiting purchase.
