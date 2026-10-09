# WudCar · وُد كار

**Your journey companion · رفيق مشاويرك**

Bilingual SwiftUI iPhone/iPad app, web administration, and Supabase backend source for individual developer **Rashed Saeed**.

## Start

- **Xcode:** open `ios/WudCar.xcodeproj`, select the WudCar scheme and an iPhone simulator. Requires Xcode with iOS 17+ SDK. No external Swift packages.
- **Website:** `npm ci && npm run dev`.
- **Checks:** `npm run check`. Browser tests: `npx playwright install chromium && npm run test:ui`.
- **Cloud setup:** [docs/SETUP.md](docs/SETUP.md).
- **Mac handoff:** [docs/XCODE-HANDOFF.md](docs/XCODE-HANDOFF.md).
- **Verified status and remaining work:** [docs/STATUS.md](docs/STATUS.md).

## Included

- Arabic/English interface and RTL, optional greeting name, guest onboarding, city and theme preferences.
- Eight approved Spirit of the UAE images: dawn/morning/sunset/night, compact and ultra-wide layouts.
- Personal HTTPS media sources, M3U playlists, imported audio/video files, favorites, AVPlayer/AirPlay and Now Playing controls.
- Email account flow, preference sync, password recovery and authenticated permanent deletion (requires cloud configuration).
- Admin authorization, theme schedules and uploads, audio library, city-targeted inbox messages and public default theme.
- Bilingual privacy, terms, support and deletion pages.
- RLS database migration, private storage, signed public catalog, authenticated account deletion function.
- StoreKit 2 service implementation **disabled pending product setup and purchase validation**.
- CarPlay audio template delegate **not activated pending Apple entitlement approval and device validation**.

## Apple identity

| Item | Value |
|---|---|
| Legal developer | Rashed Saeed — Individual |
| Bundle ID | `com.azpixel.wudcar` |
| Team | `QS29RVJPUT` |
| CarPlay Audio/Video | Requests submitted; approval pending |
| Push Notifications | Not enabled |
| Contact | az.studio971@gmail.com |

Custom theme screenshots are phone previews. They do **not** replace the CarPlay system wallpaper. Video browsing in supported vehicles needs the appropriate Apple entitlement and supported SDK/vehicle. The current target deliberately uses no unapproved entitlement.

This repository is a development build, not an App Store submission or a claim of App Review approval. No subscription charges are active.
