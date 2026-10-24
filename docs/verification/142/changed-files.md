# Files changed from build 17 baseline

| File | Purpose |
| --- | --- |
| `WdCar/App/AppState.swift` | Compact car connection text and removal of the unsupported-video toast. |
| `WdCar/App/Settings.swift` | Driving video lock default changed to true only. |
| `WdCar/CarPlay/CarTemplateUI.swift` | Four tabs, video library, settings under Home, paginated media/source lists and template depth checks. |
| `WdCar/Media/ExternalSubtitles.swift` | Local SRT/VTT parsing and phone caption state. |
| `WdCar/Media/MediaLibrary.swift` | App-private imports, metadata, thumbnails, playlists, favorites and playback progress. |
| `WdCar/Media/MediaLibraryView.swift` | Phone library, photo/file/folder pickers, media and playlist management. |
| `WdCar/Media/MediaSettingsView.swift` | Persisted player preferences and reset controls. |
| `WdCar/Media/PlayerControls.swift` | Phone playback controls and external subtitle import. |
| `WdCar/Phone/CarScreenSheet.swift` | Compact green/gray connection state. |
| `WdCar/Phone/HomeView.swift` | CarPlay status, Library/IPTV/Entertainment/Settings cards and new tab indices. |
| `WdCar/Phone/IntroView.swift` | Additional WudCar Media Player identity line. |
| `WdCar/Phone/LegalViews.swift` | Bilingual legal/help documents and legal-page subscription period formatting. |
| `WdCar/Phone/RootView.swift` | Home, Library, M3U IPTV Player, Settings; original subscription gating retained. |
| `WdCar/Phone/SettingsView.swift` | Player section, car tools, legal/help ordering and unchanged subscription access. |
| `WdCar/Shared/PlaybackManager.swift` | Queue, resume, rate, remote skip commands, media track/style settings, buffer, sleep timer and presentation. |
| `WdCar/Xtream/M3UPlaylistStore.swift` | Synchronize channel favorites/source deletion with media library. |
| `WdCar/Xtream/XtreamModels.swift` | Clean library references when removing a source. |
| `WdCar/Xtream/XtreamViews.swift` | M3U IPTV Player labels and channel-to-library/playlist menus. |
| `WdCarTests/Release142PlayerTests.swift` | Tests for lock default, audio import/copy, playlists, positions, removal, subtitle parsing/skip and screen attachments. |
| `codemagic.yaml` | New workflow only, stable native tests, build numbering, signing checks and internal-only upload without review. |
| `docs/appstore/1.4.2/metadata-ar.md` | Prepared store metadata, review draft or verification evidence; not submitted to App Store Connect. |
| `docs/appstore/1.4.2/metadata-en.md` | Prepared store metadata, review draft or verification evidence; not submitted to App Store Connect. |
| `docs/appstore/1.4.2/reply-to-review.md` | Prepared store metadata, review draft or verification evidence; not submitted to App Store Connect. |
| `docs/appstore/1.4.2/review-notes.md` | Prepared store metadata, review draft or verification evidence; not submitted to App Store Connect. |
| `docs/appstore/1.4.2/sample.m3u` | Prepared store metadata, review draft or verification evidence; not submitted to App Store Connect. |
| `docs/appstore/1.4.2/screenshots/README.md` | Prepared store metadata, review draft or verification evidence; not submitted to App Store Connect. |
| `docs/verification/142/CONTINUATION.md` | Prepared store metadata, review draft or verification evidence; not submitted to App Store Connect. |
| `docs/verification/142/HANDOFF.md` | Prepared store metadata, review draft or verification evidence; not submitted to App Store Connect. |
| `docs/verification/142/baseline-checks.txt` | Prepared store metadata, review draft or verification evidence; not submitted to App Store Connect. |
| `project.yml` | Release marketing version 1.4.2 and initial build 15. |
| `scripts/verify_142_baseline.py` | Protect baseline browser, subscription, entitlements and Info.plist. |
| `scripts/verify_142_structure.py` | Verify tab/status/picker/preferences and internal-only publishing invariants. |
| `web/src/policies.js` | Matching bilingual player legal/help content. |

SubscriptionView.swift, SubscriptionStore.swift, WudCar.storekit, Info.plist, entitlements and all protected browser files have no diff from baseline. No pre-existing native test source was changed.
