# WudCar implementation status — 2026-10-09

This is an initial integrated development build. Source implementation, local verification, live cloud deployment, device validation and App Review are separate milestones.

| Area | Actual status |
|---|---|
| Web production bundle | `npm run build` passed |
| Domain tests | Five passed: schedule boundaries, invalid schedules, greeting, aspect ratio, M3U |
| Database security | PGlite PostgreSQL test passed with stub Auth/Storage schemas: migration executes, own-profile isolation, admin access, role escalation blocked, invalid publication blocked, deleted-user rows/messages inaccessible |
| Web interaction | Happy DOM test passed: RTL/LTR, period/layout selection, greeting, policies and unavailable-admin state |
| Real browser tests | Three Playwright tests passed in real Chromium on GitHub Actions run 37943418560; local browser download was unavailable |
| iPhone | GitHub macOS Xcode build found a missing SwiftUI import in PlayerService; fixed locally, awaiting repeat build. Device validation remains pending |
| Artwork | Original local PNGs decode successfully. Replaced unreadable repository copies with matching original designs; generated separate 1024px app icon |
| Cloud | Supabase schema/functions written; no project provisioned or live E2E verification |
| Hosting | Netlify configuration ready; local CLI not signed in and connected plugin did not expose deploy operation. No live URL claimed |
| CarPlay Audio | Delegate implementation prepared; base app excludes CarPlay scene/entitlement until approved |
| CarPlay Video | AirPlay playback available in source. iOS 27 video-browsing CarPlay integration and entitlement/device tests remain pending |
| Subscription | Verified StoreKit transaction service implemented, but disabled; products/pricing/purchase UI/trial enforcement and sandbox tests remain pending |
| Account deletion | Confirmation UI and authenticated server function implemented; local schema cascade tested; live Auth deletion must be verified after deployment |
| Weather / prayer / adhkar | Not yet implemented. No fabricated live data or prayer times are shown |
| Advanced themes | Static bundled/remote image scenes and four time slots implemented. Video backgrounds, drag placement, widget extensions, complete offline remote caching not implemented |
| Legal text | Bilingual privacy/terms/support/deletion drafts included. Review against final deployed providers/features before store submission |

## Verification flow

Story: user opens the bilingual site → previews a theme/name → opens admin → authorized admin edits content through Supabase → iPhone downloads curated catalog.

The public DOM interaction and build are verified. The first unverified live boundary is the cloud connection: no Supabase URL/key/project is configured. The admin UI therefore explicitly blocks sign-in and does not show fictional saved content. Database access rules were exercised separately in local PostgreSQL (PGlite), not represented as proof of hosted Auth or Storage operation.

## Known limits to finish

- Complete real browser/simulator/device tests, VoiceOver/Dynamic Type and locked-device audio.
- Provision Supabase; apply migration and role bootstrap; deploy functions; configure SMTP/recovery origin; run full two-user/admin tests.
- Configure and verify Netlify Git deployment; make legal/support pages publicly reachable for Apple.
- Refresh signed media URLs for sessions longer than an hour; cache successful remote artwork with storage limits and fallback.
- Add real provider-backed weather and clearly attributed/validated prayer data if retained in scope. City selection currently stores preference only.
- Improve CarPlay library refresh while already connected, playlist browsing, and current-SDK video integration after entitlement approval.
- Add subscription purchase UI, introductory eligibility, secure actual-use trial accounting, sandbox renewals/refunds/restore tests before enabling monetization.
- Review privacy manifest, App Store privacy declarations, export compliance, age rating, content rights and review notes against the final release.

## Apple references

- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion
- https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements
- https://developer.apple.com/videos/play/wwdc2026/212/

Apple identity is based on the developer's supplied registration record. Submitted entitlement requests are not approved entitlements.
