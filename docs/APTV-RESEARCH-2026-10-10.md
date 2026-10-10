# APTV research and WudCar scope update — 2026-10-10

## Verified request receipt
After the user reported accepting/submitting the CarPlay form, the signed-in Apple page displayed "Thank you for your submission" and stated that Apple would review the request and contact the developer with a status update.
The form had previously been set to Video. The receipt does not expose the submitted fields, case number, or entitlement approval. Do not claim Apple granted WudCar video or browser permission.

## APTV evidence
The matching product is APTV by Suzhou Xiying Guangnian Technology Co., Ltd, App Store ID 1630403500. A targeted Google Play search did not establish a matching Android listing.
The App Store listing shows version 1.5.12, October 1, with iOS 27 compatibility.
The developer's CarPlay page advertises direct channel/local-video playback, phone remote selection, shared favorites/history/settings, and DLNA reception of video URLs. It explicitly distinguishes its DLNA receiver from AirPlay and screen mirroring and lists iOS 26.4–27.0.
A first-hand issue on the developer's repository describes YouTube direct playback and a browser on BMW CarPlay. Other first-hand issues describe the Quick tab disappearing on iOS 27.2 beta. These are user reports, not developer guarantees or Apple approval documents.
No public entitlement approval document, permission for a general CarPlay browser, or verified technical parked-state enforcement was found. The presence of APTV in App Store establishes availability, not the exact entitlements or approval conditions.

## Revised WudCar Entertainment requirements
The previous scope exclusion must not be interpreted as permanently cancelling the user's browser request. Keep it as a requested feature pending Apple's explicit clarification and technical validation.
Target experience: Entertainment -> Browse -> supported website shortcut (including YouTube where authorized) -> playback while parked; also Favorites, Recents, authorized M3U/HLS and local video.
Use original WudCar branding and design. Do not promise exact APTV compatibility or copy its proprietary implementation.
Implement the approved CarPlay video route using the current Apple APIs and vehicle-reported video availability. Ask Apple specifically whether a general web browsing UI/video website playback is permitted for WudCar and through which public APIs. Do not infer permission from a competitor.
No browser or video code has been added, no unapproved API has been enabled, and no new build has been uploaded by this research update.

## Sources
- https://apps.apple.com/us/app/aptv/id1630403500
- https://aptv.app/carplay
- https://github.com/Kimentanm/aptv/issues/184
- https://github.com/Kimentanm/aptv/issues/179
- https://developer.apple.com/videos/play/wwdc2026/212/
