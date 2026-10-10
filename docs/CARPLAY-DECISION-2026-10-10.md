# WudCar CarPlay decision — 2026-10-10

## Verified platform support
- iOS 26 CarPlay supports WidgetKit systemSmall widgets, separately from a full CarPlay app entitlement. These appear in CarPlay's widget area; they do not replace the dashboard or reproduce an arbitrary iPhone screen.
- iOS 27 introduces the CarPlay video app category for vehicles supporting video in car. Playback uses AirPlay; browsing uses CarPlay templates. The vehicle determines video availability; audio-only fallback may apply.
- Audio and video entitlements are separate. Neither TestFlight approval nor another app's presence proves WudCar is authorized.

## Account observation
App ID com.azpixel.wudcar, team QS29RVJPUT.
The Capability Requests page displayed "No Status" for CarPlay Audio App. This does not establish approval, rejection, or a pending request. Its status link opens the general entitlements support contact page.
The CarPlay request form includes Video. Selecting Video shows the CarPlay Entitlement Addendum (Rev. 06-08-2026) and an Agree checkbox/button before further request fields.
No new video request has been submitted and no agreement has been accepted during this verification.

## Product scope
Retain phone settings and prepare actual WidgetKit extensions for suitable information such as prayer times and weather, subject to implementation and validation.
Exclude from the CarPlay release scope: an arbitrary themed dashboard replacing Apple's dashboard; a general browser under the audio entitlement; any parked-video claim for all CarPlay vehicles.
Library/Entertainment on CarPlay should use supported audio/video media and Apple's browsing templates. Opening an arbitrary webpage is not equivalent to supporting an AirPlay-compatible video source. Request Apple's clarification about web-origin video, without claiming browser permission.
Current build 1.1.1 (111) has not gained WidgetKit or video implementation through this documentation change. No app code was removed or changed here.

## Draft video entitlement request (not sent)
WudCar (com.azpixel.wudcar), developed by Rashed Saeed, team QS29RVJPUT, with product branding AZ Pixel Digital Solutions, requests the CarPlay Video entitlement for its Library and Entertainment experience.
We plan to let users configure their media library on iPhone, then browse and play authorized video content through CarPlay templates in supported vehicles while parked. Playback will support AirPlay video streaming and respect vehicle-reported video availability, with audio-only behavior where suitable. We will not replace the CarPlay dashboard or circumvent vehicle restrictions or content protections.
The current distributed build does not yet implement this video integration. Please advise whether video originating from user-selected web pages can be supported when the provider exposes an authorized, AirPlay-compatible playback stream, and what restrictions apply. We are not requesting an unrestricted web browser under the audio category.
Please also clarify the status of any existing WudCar audio/video entitlement requests and the steps required for distribution approval.

## Official references
- https://developer.apple.com/carplay/
- https://developer.apple.com/videos/play/wwdc2025/216/
- https://developer.apple.com/videos/play/wwdc2026/212/
- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.carplay-video
- https://developer.apple.com/contact/request/carplay/
