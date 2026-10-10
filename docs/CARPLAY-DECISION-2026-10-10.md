# WudCar CarPlay decision — 2026-10-10

## Verified platform support
- iOS 26 supports WidgetKit systemSmall widgets in CarPlay's widget area. They do not replace Apple's dashboard.
- iOS 27 introduces CarPlay video for supporting vehicles using AirPlay playback and native browsing templates. Vehicle-reported video availability controls presentation.
- Audio and video entitlements are separate. TestFlight acceptance does not grant either entitlement or guarantee operation in every vehicle.

## Verified WudCar account state
Apple's October 9 confirmation assigns CarPlay Audio App (CarPlay framework) to the developer team. On October 10 it was enabled for com.azpixel.wudcar and the App Store profile was regenerated. The downloaded profile contains com.apple.developer.carplay-audio = true.
The Video request was submitted after the user accepted the addendum. Apple's acknowledgment confirms receipt, not approval. The follow-up received another automated acknowledgment; no video approval or general CarPlay browser permission has been verified.
The follow-up requests parked-video review and clarification of a CarPlay-display browser, URL favorites/shortcuts, YouTube and Arabic/English system input. Default-browser entitlement documentation describes acting as the default web browser, not permission to display websites in CarPlay.

## Required product experience
The iPhone app organizes favorites, shortcuts and preferences. The user requires opening those links and browsing on the CarPlay display, as demonstrated in their reference video. An iPhone-only browser does not complete this requirement.
Use Apple's public APIs and approved capabilities. Implementation must honor system/vehicle restrictions. Do not use private APIs, bypass content protections or claim that Audio authorizes web/video rendering.
WidgetKit integration and vehicle video/browser integration remain implementation and validation work.

## Current implementation
Build 112 source registers a CarPlay template scene in Info.plist, supplies the approved Audio entitlement and presents the initial screen before network refresh. The temporary AppDelegate scene-configuration override was removed; phone launch works with the static manifest.
The current CarPlay scene is an audio-template experience. It does not implement the requested car browser/video or a custom Arabic keyboard.

## Runtime validation
On October 10 the iPhone 17 Pro simulator (iOS 26.5) initially ignored clicks in all CarPlay apps, including built-in Settings. Disabling keyboard capture alone did not restore clicks. After quitting Simulator and relaunching WudCar from Xcode, built-in CarPlay Settings opened by mouse. WudCar then opened its Arabic home template and the Entertainment list successfully. The list displayed its empty state because no tracks were available for the selected theme/library.
This verifies launch and navigation, not audio playback, browser/video, rotary-controller behavior or physical vehicle compatibility. Native CarPlay templates are used; the preview is not a specific car model.
Signed distribution and physical-car testing remain required. Build 112 has not been uploaded to TestFlight. Uploaded build 111 must not be described as the completed CarPlay Entertainment experience.

## Official references
- https://developer.apple.com/carplay/
- https://developer.apple.com/documentation/carplay/using-the-carplay-simulator
- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.web-browser
- https://developer.apple.com/videos/play/wwdc2025/216/
- https://developer.apple.com/videos/play/wwdc2026/212/
- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.carplay-video
- https://developer.apple.com/contact/request/carplay/
