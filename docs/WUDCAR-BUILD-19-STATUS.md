# WudCar 1.6.0 (19) — Video-only internal comparison

Base: owner-tested build 17 branch head `6ca24bc877495dbaed55ff2aa833e687fa4e058f`. Branch: `develop/wudcar-build-19`.

Owner explicitly authorized an internal TestFlight experiment with CarPlay Video only after the Audio-only build 18 failed physical CarPlay acceptance. This is not the entitlement configuration requested in the App Review rejection of 1.4.2 (14), and does not imply permission to submit it to App Store. No Apple reply, review resubmission or production merge is authorized by this experiment.

Scope: remove Audio from build 17's app entitlements; retain Video=true; marketing version stays 1.6.0; increment build to at least 19. Keep existing Bundle ID `com.azstudio.wudcar`, certificates, profiles and all application source/UI/browser/player/data untouched. Both signed workflows verify Video=true, Audio key absent (even false is rejected), and the provisioning profile authorizes Video. Profile authorization may be a superset of the app's requested entitlements.

Local checks passed: Video-only source plist; one valid signed/profile case; five invalid entitlement scenarios rejected; YAML parsed with both signed gates and build minimum 19; logo integrity unchanged. No native/physical success is claimed before the corresponding test results.

Physical acceptance pending: app visibility on connected CarPlay, original home/grid appearance, browser desktop layout, toolbar, phone mouse controls, TV playback/audio, fullscreen and exit/reopen. Simulator tests host the car controller directly and cannot establish entitlement-dependent CarPlay scene activation. Video-only apps may not appear on vehicles without supported video capability; owner must verify on the actual setup.

Build 18 remains failed owner acceptance; build 17 is the working reference. Internal TestFlight only, no change description, external beta review or App Store submission.

## Signed build verification

Source commit: `89166614dbe4773e1f7a21fd30e8876d42a1237f`. Codemagic build `6ada80c68a524d15d6a62ebf`.

Eight native tests passed, zero failures, in 95.842s. Release160 tests passed in 77.158s and Release17 tests in 18.684s. Live YouTube phone-before-car-controller probe passed in 59.448s: both CSS viewports 1280, desktop=true/mobile=false, pageZoom=1.0; channel navigation and back stable. Simulator results do not certify physical CarPlay activation or vehicle support.

The exported signed IPA gate passed: CarPlay Video only, Audio absent, profile authorizes Video; actual marketing version 1.6.0, build 19. Existing CPTemplateApplication and external-display scene roles are present. No application source code changed relative to build 17.

## Upload transport result

Codemagic completed build/tests/archive checks, but its Publishing step reported an Apple server HTTP 500 after altool also printed UPLOAD SUCCEEDED, delivery UUID `98b772a6-b9b5-4342-9667-755e7e95ed41`. Do not call the entire Codemagic run successful: its final status is failed due to publishing. App Store Connect initially returned a Build Uploads error as well. Subsequent direct UI verification confirmed 1.6.0 (19) was received and Processing, dated October 23, 2026 at 01:39 UAE time. No duplicate upload or new build was started.

## Final delivery

Apple processing completed. The WudCar Internal group shows 19 builds, one tester and 1.6.0 (19) status Testing with 90-day expiry. Verified directly in App Store Connect. No duplicate upload was necessary despite the transport status error. Proof: `verification/19/testflight-1.6.0-19-testing.png`.

Independent GitHub run `39857858430`, source `89166614dbe4773e1f7a21fd30e8876d42a1237f`, completed successfully: all 13 native tests passed, zero failures, 134.741s; live YouTube probe 78.355s with stable phone/car-controller desktop navigation. Web checks and UI tests also passed. Native log job: `120100626668`.

Physical owner testing remains pending, particularly entitlement-dependent app visibility and original custom car-screen activation. No TestFlight change description, external beta review, App Store resubmission, Apple reply or production merge was performed. Build 18 remains failed physical acceptance; build 17 remains the working reference.
