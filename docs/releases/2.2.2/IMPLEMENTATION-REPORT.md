# WudCar 2.2.2 — development candidate

Date: 23 October 2026 (Dubai). This candidate is not approved for App Review submission.

## Baseline and identity

- Base branch: `develop/wudcar-build-17`.
- Initial application-source commit: `03041a08fd9668ae16e2e75e33404bc1ae1288b0`. Latest build-17 head `6ca24bc877495dbaed55ff2aa833e687fa4e058f` is incorporated, including its icon fixes, evidence and corrected non-square SF Symbol test. Swift application sources were unchanged between these baseline commits.
- Base `project.yml`: marketing version 1.6.0, build 17.
- New branch: `develop/wudcar-2.2.2-media`; previous branches remain unchanged.
- Target: 2.2.2, source build floor 222. Inspected active project branches contained builds through 19. The legacy project generator also contains build 111. The final signed build number must be allocated from verified App Store Connect data: max(222, latest TestFlight build + 1). No final signed build is claimed yet.
- Final identity confirmed by the user on 23 October 2026: `com.azstudio.wudcar`, team `QS29RVJPUT`. This matches the build-17 delivery report and existing App Store application rather than the `com.azpixel.wudcar` identifier initially requested. Configuration and signing audit now preserve that existing identity.
- Existing StoreKit product ID `com.azstudio.wudcar.premium.monthly`, prices, access logic and subscription source are unchanged.


## Implemented in source

| Area | Behavior |
| --- | --- |
| Library | Persistent metadata, direct HTTP(S) sources in Keychain, multi-file Photos/Files import with progress/errors, private copies, offline local URLs, optional duration/thumbnail, search, recent/name sorting, favorites, history and resume position |
| Source integration | Existing M3U/Xtream setup retained; played sources join the library; removing a source removes its cached playback credentials/library entries, while separately saved manual links remain user-managed |
| Player | Existing AVPlayer/AVPlayerViewController extended with queue, previous/next, resume, source-bounded seeking including real live seekable windows, skip intervals, available rates, loading/errors, native audio/embedded subtitle tracks, fit/fill |
| External captions | SRT/VTT parser and iPhone overlay; size/color/background/delay controls; explicitly not sent to AirPlay/CarPlay/PiP |
| Storage | Imported-copy deletion preserves Photos/Files originals, storage usage, no overwrite of unreadable metadata |
| CarPlay | Shared library, Favorites/Continue watching within lists; Library/TV/Entertainment/Settings order; group into a list when tab capacity is insufficient; native playback configuration, no intro bootstrap; pause app-initiated car media on disconnect |
| Browser | Browser/chrome/shortcuts source unchanged; existing optional GPS pause setting defaults to true for unset values, existing saved preferences retained; no new override of system restrictions |
| Mouse | Existing touchpad source unchanged; access moved from phone tab/Home card to Settings |
| Entitlements | Audio-only default; separate Audio, Video and Combined experiment files; signed IPA audit of exact entitlements, bundle/team and profile grants |
| Build | Manual Codemagic workflow `wudcar-222-media-validation`, internal TestFlight publishing only, no App Store submission; GitHub macOS validation workflow |

## Limits and unresolved requirements

- **Not implemented:** DLNA/UPnP receiver and whole-iPhone screen sharing. AirPlay sender support is not an AirPlay receiver. No new receiver or mirroring buttons are shipped. No local-network/multicast permissions are requested for unimplemented features.
- **Not validated on physical equipment:** AirPlay video delivery, local-file CarPlay video, native video-to-audio policy transitions, unknown-state behavior and vehicle reconnect. Native media is routed through system presentation; `supportsVideoPlayback` is treated as capability, not parked permission. No GPS-only parked authorization is added to native media.
- **Release blocker:** legacy custom external browser remains and its optional GPS setting can be disabled; its unchanged movement detector has a threshold around 9 km/h and does not prove parked state. Default-on is not compliance evidence. Removing bootstrap means browser activation on cars that depended on it is not preserved or claimed functional. Obtain Apple's explicit position or resolve this path before submission.
- No new setting claims to control audio fallback based on a reliable current vehicle-video-permission callback. System-native transition must be verified on a supported vehicle before claiming this requirement complete.
- Quality stays under native adaptive playback. No arbitrary manual quality choices are advertised. Embedded subtitle appearance follows AVKit/system behavior; custom appearance controls apply only to imported captions on the phone.
- M3U/Xtream real server authentication/playback tests need authorized test sources. Existing source handling is preserved, not certified against all providers or codecs.
- Imports are copied and do not delete originals. Transfer progress is per completed item, not byte-level download progress. Photo filenames may be temporary generated names; metadata is shown where available.
- External caption selections are session-only. No automatic translation or universal format support is claimed.
- No App Store metadata was changed. Draft descriptions, review notes and rejection response are in `REVIEW-DRAFT.md`; physical results and actual screenshots must be attached before submission.

## Evidence

- Local static checks passed: bundle/team/version, audio-only default, plist parsing, bootstrap removal, protected source hashes; Python scripts compile; whitespace diff check passed.
- First native CI run: https://github.com/azstudio971-lab/miznar-uae/actions/runs/39876378533 . Xcode 26.6, iPhone 17 Pro simulator, iOS 26.4.1. Full app/test target compiled; 4 media unit tests passed, 0 failures. This run covers commit `937883a58d00c53aace3827786570121f56b64ec`, not later changes.
- Expanded run https://github.com/azstudio971-lab/miznar-uae/actions/runs/39876898916 compiled and exported 8 UI attachments, but visual inspection found them blank because the test window lacked a scene. The capture test was corrected to attach to a scene and reject blank images. The run also failed: StoreKit returned `notEntitled`, and an older baseline toolbar test assumed square SF Symbols. The newer build-17 test correction is incorporated without changing browser code. A stable iOS 18.5 StoreKit runtime is selected for the next run; success is not assumed.
- Final application-source validation passed: https://github.com/azstudio971-lab/miznar-uae/actions/runs/39878005499 , commit `ed5f145db1b788cb59d963d0f5900641a6d42b0a`. Xcode 26.6, iPhone 16 Pro simulator, iOS 18.5: **10 tests, 0 failures**, 337.264 seconds. Includes imported-copy readiness/queue/removal, SRT/VTT parsing, metadata credential isolation, 3 build-17 shortcut/toolbar regressions, and the complete existing StoreKit lifecycle test. This is not physical video-output or manual resume verification.
- Corrected screenshot capture produced 8 nonblank library/player-settings images in Arabic/English and light/dark appearances. Arabic light library and English dark player settings were visually inspected. The library is shown empty after test cleanup; these are technical UI captures, not final App Store marketing or physical-car screenshots.
- Download test results/screenshots: https://github.com/azstudio971-lab/miznar-uae/actions/runs/39878005499/artifacts/12469204404 . Artifact expires 21 January 2027. Filtered logs are preserved in `docs/verification/222/RESULTS.txt`.
- Signed audit has not run: no candidate signed IPA supplied or generated in this session yet. Certificates and developer account are unchanged.
- Codemagic/Apple credentials are not exposed through the available tools; preparing its workflow does not establish that TestFlight received a build.

## Physical acceptance record required before submission

Record exact commit, signed build, iPhone/iOS, car/head-unit model and firmware, connection type, video capability, stationary/blocked/unknown conditions, expected result and actual result. Test Audio/Video/Combined separately with identical content and identity. Include native stream, imported local video, phone AirPlay, browser, reconnect and subscription restore. Receiver/screen-sharing tests are N/A until implemented; do not mark them passed.

Do not submit this candidate to review or production merely because a simulator build succeeds.

## Primary API references

- Apple CarPlay Developer Guide: https://developer.apple.com/download/files/CarPlay-Developer-Guide.pdf
- Video capability is not current playback permission: https://developer.apple.com/documentation/carplay/cpsessionconfiguration/supportsvideoplayback
- Native route picker: https://developer.apple.com/documentation/avkit/avroutepickerview
