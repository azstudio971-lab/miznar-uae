# Deployment and account setup

## Supabase

No project was available in the connected organization at the time of implementation. Cloud flows are written but must be deployed and tested against an actual project.

1. Create a Supabase project after confirming the plan/cost. Select a suitable region and record data processing terms.
2. Apply `supabase/migrations/20261009140504_initial_schema.sql` using a migration deployment. It creates tables, RLS policies, private storage and the built-in theme record.
3. Deploy `catalog` and `delete-account` from `supabase/functions/`. Both have gateway JWT checks disabled deliberately: catalog serves a curated public response; deletion **verifies the bearer with Auth getUser** and derives the identity server-side. Never remove that check.
4. Configure `ALLOWED_ORIGINS` on functions to exact HTTPS web origins, comma-separated. Native apps have no Origin header. Keep the service role key only in Edge Function runtime secrets.
5. Enable email confirmation; configure production SMTP, password requirements, rate limits and short-lived access tokens. Set Site URL to the deployed site and allow its `/reset-password` redirect. iPhone recovery emails use this web recovery page.
6. Create the owner's normal Auth account. Privileged SQL editor only: insert the verified owner's UUID into `public.admin_roles`. Never put the service role key in the dashboard or allow self-assignment of roles.
7. Test with two ordinary users and one admin. Ordinary users must not read each other's profiles, edit roles, edit themes, or access storage directly. Delete a test account and verify Auth/profile removal and rejection of a still-unexpired old token on sensitive operations.

Deletion revokes refresh sessions then hard-deletes Auth. Profile and admin-role rows cascade. Existing signed theme URLs may remain valid for one hour; they contain public theme media, not personal records. Deleted-user access tokens are not cryptographically revoked by deletion; RLS messages additionally checks the user still exists, profiles require existing owner rows/FK, and admin membership is removed.

## Web / Netlify

Existing site: `miznar-uae` (`45789260-5610-4e67-8cb2-f3e6855253f1`). Avoid making duplicate sites.

- Git repository: `azstudio971-lab/miznar-uae`, branch `main`.
- Build: `npm ci && npm run build`; publish directory: `dist`.
- Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` through hosting settings; rebuild. These are public client values, not server secrets.
- `netlify.toml` includes SPA routes and response security headers.
- `/admin` checks authenticated membership via RLS. Website visibility protection is separate from app-user/admin authorization.
- Apple must be able to open `/privacy`, `/terms`, `/support` and `/delete` without a hosting sign-in wall. The previously observed site-wide protection needs adjustment before submission. Admin stays protected by app auth regardless.
- The current connector did not expose a deployment upload or Git-build configuration operation, and local CLI was not authenticated. A live deployment is not claimed.

## iOS

Copy `ios/Local.xcconfig.example` to ignored `ios/Local.xcconfig`, use the real public URL/key, and open the committed `.xcodeproj`. The escaped URL syntax `https:/$()/...` avoids xcconfig treating `//` as a comment. No secrets belong in build settings.

`python3 scripts/generate_xcode.py` rebuilds the project deterministically from source, restores approved assets and produces the 1024px App Store icon. On macOS it uses built-in `sips`; on Linux the script needs Pillow. Source designs remain unchanged.

Base `Info.plist` excludes the CarPlay scene declaration. Only after approval, select `Info-CarPlay.plist`, create the approved entitlement file from its example, set CODE_SIGN_ENTITLEMENTS, and regenerate the provisioning profile. Do not add Video entitlements or guessed SDK APIs.

## Pre-release requirements

- Verify iOS build, playback/lock screen/AirPlay behavior and accessibility on real hardware.
- Deploy cloud and verify registration, confirmation, recovery, sync, admin publication and deletion end to end.
- Ensure uploaded media licensing, metadata accuracy and support email operation.
- Configure App Store privacy answers to match the final build; verify the bundled privacy manifest against actual APIs/dependencies.
- Configure StoreKit subscription group, localized products, pricing, eligibility, restore and subscription management before enabling paid UI. No fixed AED price is presented as storefront data.
- A planned 30-minute actual-use allowance is **not implemented as a secure production entitlement**. Do not enable paid gating until persistence/abuse handling and purchase tests are complete.
