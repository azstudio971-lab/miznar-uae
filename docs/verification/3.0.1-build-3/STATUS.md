# WudCar 3.0.1 (3) development verification checkpoint

Based on release/wudcar-3.0.1 (5da7464) plus the owner-requested build2 scene-routing fixes and later settings relocation. No production merge or review submission.

Subscription correction: keep the existing monthly product, eligible3-day free introductory trial and AED24 UAE price, all features included. No new plan, access-policy, source cap or timed feature limits. SubscriptionStore, SubscriptionView and WudCar.storekit remain unchanged.

Implemented pending native validation: source parsing and encrypted cache; M3U URL/text/config/single stream; Jellyfin/Emby login and hierarchy; Plex PIN and owned direct servers; QR camera/photo; recursive folder import into a named playlist; software phone decoder using pinned official VLCKit; HLS quality preferences; persistent external subtitles and Apple Translation; Cast media routing, optional ReplayKit frame relay for existing external scenes, local widget/Live Activity and four native CarPlay tabs Library/TV/Favorites/Cast.

No assertion of vehicle support or successful physical casting. ReplayKit captures video frames only; protected content and background execution remain subject to iOS restrictions. AVPlayer is required for car media. New extensions require valid App Group profiles before an archive can be uploaded.

24 core browser/input/catalog files remain byte-identical to build17;3 template browser methods verbatim. Two scene-routing adapters are explicit exceptions required for the prior owner routing correction and external presentation. Do not claim the complete original26-file diff is empty.

Native compile, tests, image inspection, signed capabilities and build3 upload are pending. The earlier3.0.1(2) job finished and uploaded successfully (6adb82f74a72334e32e472d4); it does not contain these additions.

Outstanding work under review: full cross-source search/history/voice UI; complete logical local folders/bulk selection; external subtitle rendering on remote AirPlay; software playback track/display edge cases; vehicle-specific CarPlay search availability; screenshots and updated store drafts. No claim that the entire attached specification is complete.

## Second implementation checkpoint

- Validation job6adb96844a72334e32e478df compiled the new targets until one SourceStore initializer error (optional directory parameter shadowing the computed directory). Fixed with self.directory; no native tests ran in that attempt.
- Added cross-source search and local search history/voice UI, logical folders and bulk selection, general/group filters, expired Xtream account status parsing, audio playback animations, native player-only zoom/actual size controls and saved quality preference.
- Registered group.com.azstudio.wudcar and associated the main app plus com.azstudio.wudcar.ScreenRelay and com.azstudio.wudcar.CastWidget. Generated App Store profiles with the existing October16 certificate, imported to Codemagic as wudcar-303-main, wudcar-303-relay and wudcar-303-widget. Existing certificates were retained.
- CarPlay search currently uses the explicit iPhone-search fallback. CPSearchTemplate audio/video-category eligibility on iOS27 has not been verified on an available SDK/device; do not assert it is implemented or Apple-forbidden. External subtitle overlays are phone-only; remote AirPlay still requires embedded subtitle tracks.
