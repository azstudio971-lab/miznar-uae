# WudCar CarPlay decision — 2026-10-10

## Verified platform support
- iOS 26 supports WidgetKit systemSmall widgets in CarPlay's widget area. They do not replace Apple's dashboard.
- iOS 27 introduces CarPlay video for supporting vehicles using AirPlay playback and native browsing templates. Vehicle-reported video availability controls presentation.
- Audio and video entitlements are separate. TestFlight acceptance does not grant either entitlement or guarantee operation in every vehicle.

## Verified WudCar account state
Apple's October 9 entitlement confirmation assigns CarPlay Audio App (CarPlay framework) to the developer team. On October 10 this capability was enabled for com.azpixel.wudcar and the App Store profile was regenerated. The downloaded profile contains com.apple.developer.carplay-audio = true.
The Video request was submitted after the user accepted the addendum. Apple's acknowledgment confirms receipt, not approval.
A follow-up was sent to Apple's CarPlay Entitlements team requesting parked-video review and explicit clarification of a CarPlay-display browser, URL favorites/shortcuts, YouTube, and Arabic/English system input. No video approval or general browser permission has been verified.

## Required product experience
The iPhone app organizes favorites, shortcuts and preferences. The user requires opening those links and browsing on the CarPlay display, as demonstrated in their reference video. An iPhone-only browser does not complete this requirement.
Use Apple's public APIs and approved capabilities. Parked-only wording is insufficient: implementation must honor the system/vehicle restrictions. Do not use private APIs, bypass content protections or claim that Audio authorizes web/video rendering.
WidgetKit integration and vehicle video/browser integration remain implementation and validation work.

## Current implementation and validation limits
Build 112 source registers a CarPlay template scene, supplies the approved Audio entitlement, routes CarPlay connections to its delegate, and presents the initial screen before network refresh.
The existing CarPlay scene is an audio-template experience; it does not implement the requested car browser/video or a custom Arabic keyboard.
Simulator icon visibility has been observed. Successful app launch, audio playback, signed distribution and physical-car testing remain required. No new TestFlight build has been uploaded from these changes.
The existing uploaded build 111 must not be described as the completed CarPlay Entertainment experience.

## Official references
- https://developer.apple.com/carplay/
- https://developer.apple.com/videos/play/wwdc2025/216/
- https://developer.apple.com/videos/play/wwdc2026/212/
- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.carplay-video
- https://developer.apple.com/contact/request/carplay/
