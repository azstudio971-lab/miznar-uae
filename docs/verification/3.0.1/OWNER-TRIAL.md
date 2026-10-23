# Owner-requested internal trial — 2026-10-23

After receiving the failed-suite status, the owner explicitly requested uploading this candidate to TestFlight to personally exercise the features and report issues. This is internal testing approval, not release acceptance or App Store submission approval.

The dedicated owner-trial workflow archives the exact app source tested at `f14d3265dea56641f9aa4fed67f25594c60cefec`, without repeating simulator tests. A git-diff gate verifies Config, WdCar and project.yml are identical to that source. The frozen-browser and signed Audio+Video entitlement gates remain mandatory. The original full-test workflow remains unchanged.

## Existing evidence, without claiming all tests passed

GitHub run https://github.com/azstudio971-lab/miznar-uae/actions/runs/39953949991 completed with failure:
- Native app compilation and web checks/UI tests passed.
- All six Media301Tests passed, including actual legal Apple HLS playback with advancing playback time, local imports/thumbnail/duration, playlists/order/resume persistence, invalid import rollback, subtitle parsing/applied AVTextStyleRules, safety default, real CarPlay tab order, and ten native phone-view image captures.
- All five Release150Tests, all five Release160Tests, all three Release17Tests and SubscriptionTests passed.
- Live YouTube phone-first then car-size Simulator probe passed: desktop=true, mobile=false, width=1280, pageZoom=1.0; channel navigation and back remained stable on both. This is not a physical vehicle test.
- The old CarInterface desktop preference test exceeded four minutes; the 20 remaining CarInterface tests completed with five failed assertions in two cases: obsolete Netflix/Prime defaults (two) and zoom/fullscreen fixture geometry (three).
- Overall report says 40 completed test cases with five failed assertions, plus the separately reported timeout. Do not describe the suite as green.

Codemagic build `6adb53d84a72334e32e46243` on the same source also reproduced the five old geometry/catalog assertions. HLS connection and image-capture tests timed out there, although both passed on GitHub. No cause is assumed without further investigation. This failed full-test attempt cannot publish an IPA.

Artifact: https://github.com/azstudio971-lab/miznar-uae/actions/runs/39953949991/artifacts/12503243444 (source f14d326, SHA256 887448b7c12727bd9162a0dc3de0fe1fce283603ab9febccddfd45c661451d92). Download attempts timed out; images have not yet been visually accepted or committed as store screenshots.

Build target: WudCar 3.0.1 (1), com.azstudio.wudcar, WudCar Internal only. No What to Test, external beta review, App Store metadata upload, main merge, or App Store submission. Physical CarPlay testing remains owner-only.
