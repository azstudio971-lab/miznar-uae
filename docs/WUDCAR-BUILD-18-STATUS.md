# WudCar 1.6.0 (18) — Audio-only entitlement validation

Based on owner-tested build 17, branch head `6ca24bc877495dbaed55ff2aa833e687fa4e058f`.

App Review rejected 1.4.2 (14) under 2.5.1 and specifically requested removing `com.apple.developer.carplay-video` while retaining `com.apple.developer.carplay-audio`. The CarPlay Entitlements email of October 14, case 22772031, also states that Audio supports combined audio/video services and the two entitlements must not be combined.

Scope: remove Video from the signed app, keep Audio, increment the build to at least 18, and update both existing signed build checks. The signed archive gate requires Audio=true, rejects any Video key (even false), and confirms the provisioning profile authorizes Audio. An existing provisioning profile may authorize a superset; this does not grant Video to the signed app. Account capabilities, certificates, Bundle ID `com.azstudio.wudcar`, UI, WebView, browser behavior, players and data remain unchanged.

Local validation passed: source plist Audio-only; one valid and five invalid signed/profile entitlement scenarios; YAML parsing and both workflow gates; existing logo integrity. Native tests, signed archive validation and Apple processing must be verified in Codemagic/TestFlight before delivery.

Authorization: internal TestFlight upload for owner testing only. No App Store resubmission, release metadata edit, production merge, or message to Apple. Keep marketing version 1.6.0. Owner must test physical CarPlay after this entitlement change; the simulator cannot establish vehicle behavior.
