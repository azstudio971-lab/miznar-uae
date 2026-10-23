DRAFT — DO NOT SUBMIT WITHOUT OWNER APPROVAL AND COMPLETED VERIFICATION

WudCar is a video and audio media player. We include both CarPlay Audio and Video entitlements because users add media suitable for viewing and listening, consistent with WWDC26 session 212 and the current CarPlay Audio entitlement documentation:
https://developer.apple.com/videos/play/wwdc2026/212/
https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.carplay-audio

We acknowledge that build 1.4.2 (14) received different guidance under 2.5.1. This draft does not imply that its issue is resolved or that these entitlements/any retained external browser implementation have been approved. Please evaluate the revised implementation and advise on any required changes.

A video-only app is hidden on vehicles without Video in Car support. supportsVideoPlayback indicates support, not current permission to display video. Apple controls the transition to audio when video is unavailable.

Test with public legal Apple sample HLS: https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8
M3U fixture: docs/appstore/3.0.1/sample.m3u (host or paste through a supported import route; no credentials).
1. Library → Add media URL: paste Apple HLS, title Apple sample, mark Live; play.
2. Import a rights-cleared local MP4/audio file. Play, leave, resume; create a playlist and reorder entries.
3. CarPlay: Library → TV → Favorites → Settings. Physical car acceptance remains pending owner testing.
4. Browser is an additional feature at Favorites → Play from web. First launch shows a parked/passenger notice. Phone access: Settings → Car and web tools.
5. Movement detection locks car video. Location is When In Use, transient speed only. Denied permission blocks external video unless the car reports video support; Apple policy always applies.
6. Frozen legacy browser lock pauses all web media; continuing browser audio during movement is not claimed. External subtitle files display on iPhone only.

Before submitting: replace draft statuses with actual verified results, supply reviewer subscription/demo access instructions, and attach real simulator captures. Never claim physical vehicle verification without owner confirmation.
