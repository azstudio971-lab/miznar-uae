# Reply to Guideline 2.5.1 — prepared draft only

Hello App Review Team,

Thank you for reviewing WudCar. We have prepared version 1.4.2 as WudCar Media Player, with user-imported video and audio, mixed playlists, M3U/M3U8 and Xtream sources, and a CarPlay Video Library. The existing subscription covers all features. We provide no channels or media content.

We respectfully request assessment of both existing CarPlay Audio and CarPlay Video entitlements for this combined media use case. WWDC26 session 212 describes including both entitlements when content is suitable for video and audio. Apple's CarPlay Audio entitlement documentation also permits combining the two. Video-only apps require a vehicle supporting video in car; audio provides the listening experience when the vehicle does not support video. We use the vehicle's supportsVideoPlayback capability to choose playback presentation.

Official references:
https://developer.apple.com/videos/play/wwdc2026/212/
https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.carplay-audio

The GPS video lock is on by default. Our safety text states that video viewing is for passengers while parked. The setting remains user-controllable, and the Web Player/display implementation is retained from build 17; we understand those aspects require separate policy assessment and do not claim that adding a media library guarantees compliance or entitlement approval.

Please see the accompanying review notes for the official Apple developer test stream and local-file test steps. We would appreciate clarification of any remaining changes required under Guideline 2.5.1.

Kind regards,
WudCar Media Player
az.studio971@gmail.com
