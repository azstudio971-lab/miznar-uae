# Upload evidence — WudCar 3.0.1 (1)

- Source commit archived: e85525737e1ea880e2913a7f687b65ae6fbb575e.
- Shipping app source is identical to tested commit f14d3265dea56641f9aa4fed67f25594c60cefec (git-diff gate passed).
- Codemagic: https://codemagic.io/app/6ad1db1b951fcdf1e4f45860/build/6adb5e684a72334e32e46670 .
- Archive and IPA export succeeded using Xcode 26.6 (17F113).
- Existing identity: WudCar, com.azstudio.wudcar, Team QS29RVJPUT.
- Signed-entitlement gate passed for the exported IPA and provisioning profile: both carplay-audio and carplay-video are true; get-task-allow=false.
- `signed-entitlements.txt` transcribes the complete signed entitlement dictionary printed by the successful verifier. The original generated file is also included in the Codemagic artifact bundle.
- Apple uploader: `UPLOAD SUCCEEDED with no errors` at 2026-10-23 13:27:05 UTC.
- Delivery UUID: 22e2db8c-529f-4b11-bc02-c4f34951fdfb.
- Version 3.0.1, build1, App Store distribution archive uploaded to App Store Connect for internal TestFlight only.
- TestFlight processing/group availability still to be confirmed at this upload checkpoint.
- No What to Test, external beta review, App Store review submission, metadata upload or main merge.

This owner trial is not an all-tests-passed release. See OWNER-TRIAL.md for the successful new-feature tests and the unresolved old assertions/timeouts. Physical vehicle acceptance remains with the owner.
