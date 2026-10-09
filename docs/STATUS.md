# WudCar implementation status — 2026-10-09

The binding scope is [MASTER-SPEC.md](MASTER-SPEC.md). WudCar is the only current app identity. The approved logo and eight Spirit of the UAE scenes remain the asset source of truth. Apple developer: Rashed Saeed; bundle ID com.azpixel.wudcar; team QS29RVJPUT. Audio and Video entitlement requests remain pending.

## Implemented source and verification

- Native iPhone source: onboarding and preferred name, bilingual RTL/LTR, themes, media library, account/auth/deletion, legal pages, city settings and system/light/dark appearance.
- Expanded native source: catalog cache, theme scheduling/priority, bounded image cache, rotating media, silent video backgrounds inside the phone preview, digital/analog clocks, Hijri date, per-theme widget positions and saved customization, optional music controls, WeatherKit and AlAdhan information pages, sourced religious content.
- Admin source: capability-filtered navigation, advanced bilingual theme editor, draft/scheduled/published states, two layouts and four time slots, media sequences, widget permissions, version restoration, staff roles, users/status/export, server entitlements/trial records, religious content, legal documents, audit records and password change with current-password reauthentication.
- Supabase migrations/functions: role-based row access, ownership isolation, last-super-admin guard, protected entitlement records, server-clock 30-minute trial accounting, duplicate-heartbeat protection, devices, authenticated staff operations, signed curated catalog, account deletion.
- Local check: eight domain, DOM and PostgreSQL/PGlite tests passed; Vite production build passed. Tests include role escalation, own-data isolation, trial replay and resetting prevention. PGlite uses Auth/Storage fixtures; it is not a hosted Supabase test.
- Branch checkpoint 18febf1361cb296b0aeee28eef303ea6afaf79cb: real Chromium checks passed in GitHub Actions 37953120784. Its Xcode compilation exposed syntax errors in ThemeEngine; the following checkpoint corrects them. Do not treat the earlier successful baseline Xcode run as proof that new code compiles.

## External deployment blockers

No Supabase project exists in the connected organization. The connector advertises get_cost but returns UNAVAILABLE when called, preventing the required project provisioning sequence. There is no provisioned database, production Auth user, or verified account deletion endpoint.

Netlify source/build/security routing configuration is ready. The connected plugin does not expose the required upload/build/environment mutation operations, and the local CLI is not authenticated. No Netlify deployment or live admin password activation is claimed. The old Sites preview is not the requested production host; its obsolete reference document has been removed.

The requested initial password is not committed. scripts/bootstrap-admin.mjs accepts a password interactively after a real project exists. The app-level admin password change screen is implemented; live verification remains pending.

## Remaining work before release

- Verify the expanded native source on Xcode CI, then launch the simulator and test real devices, accessibility and background audio.
- Complete subscription purchase UI, server-side Apple signed-transaction/notification verification, StoreKit sandbox purchase/renewal/refund/restoration testing, and connect the trial heartbeat to actual native active use. Payments stay disabled.
- Finish playlist administration, complete theme cloning and comprehensive version snapshot coverage, automatic refresh scheduling and rollout edge cases.
- Add supported Apple WidgetKit/CarPlay presentation only through current official APIs. Custom phone dashboard artwork is not a replacement for the CarPlay system wallpaper. Supported parked video integration needs entitlement approval and vehicle tests.
- Enable WeatherKit in Apple developer signing before expecting live weather; test source attribution, unavailable/cache states and prayer calculation against selected method. Religious content is not fabricated; only manually verified published records are displayed.
- Provision Supabase, apply both migrations, deploy functions, configure Auth recovery/SMTP and secure origins, bootstrap the owner, and run real two-user/admin/device/storage tests.
- Configure Netlify Git deployment and public support/legal endpoints; verify a real production URL and login before handing out access.
- Update legal/privacy declarations against the final active services, retention and billing behavior. Review current Apple guidelines, content rights, App Review notes and required capabilities before submission.

This is an implementation checkpoint, not a finished or published application.
