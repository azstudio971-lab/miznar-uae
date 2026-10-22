# WudCar 1.6.0 (19) — Video-only internal comparison

Base: owner-tested build 17 branch head `6ca24bc877495dbaed55ff2aa833e687fa4e058f`. Branch: `develop/wudcar-build-19`.

Owner explicitly authorized an internal TestFlight experiment with CarPlay Video only after the Audio-only build 18 failed physical CarPlay acceptance. This is not the entitlement configuration requested in the App Review rejection of 1.4.2 (14), and does not imply permission to submit it to App Store. No Apple reply, review resubmission or production merge is authorized by this experiment.

Scope: remove Audio from build 17's app entitlements; retain Video=true; marketing version stays 1.6.0; increment build to at least 19. Keep existing Bundle ID `com.azstudio.wudcar`, certificates, profiles and all application source/UI/browser/player/data untouched. Both signed workflows verify Video=true, Audio key absent (even false is rejected), and the provisioning profile authorizes Video. Profile authorization may be a superset of the app's requested entitlements.

Local checks passed: Video-only source plist; one valid signed/profile case; five invalid entitlement scenarios rejected; YAML parsed with both signed gates and build minimum 19; logo integrity unchanged. No native/physical success is claimed before the corresponding test results.

Physical acceptance pending: app visibility on connected CarPlay, original home/grid appearance, browser desktop layout, toolbar, phone mouse controls, TV playback/audio, fullscreen and exit/reopen. Simulator tests host the car controller directly and cannot establish entitlement-dependent CarPlay scene activation. Video-only apps may not appear on vehicles without supported video capability; owner must verify on the actual setup.

Build 18 remains failed owner acceptance; build 17 is the working reference. Internal TestFlight only, no change description, external beta review or App Store submission.
