# Cloud Mac / Xcode handoff

Paste this into the session with access to the signed-in cloud Mac:

> Continue WudCar for individual developer Rashed Saeed. Clone or pull https://github.com/azstudio971-lab/miznar-uae, read README.md, docs/MASTER-SPEC.md and docs/STATUS.md, and open ios/WudCar.xcodeproj. Bundle ID: com.azpixel.wudcar; Team ID: QS29RVJPUT. Build and run the WudCar scheme on an iPhone simulator, fix compile/runtime issues, then test Arabic RTL and English, guest onboarding, preferred-name greeting, all eight theme assets, local and HTTPS media, M3U, background audio and AirPlay. Test widget movement permissions and persisted settings, video preview fallback, cached/offline themes, device management, prayer calculation and required Apple Weather attribution. Enable WeatherKit signing only through the proper Apple account capability. Configure real Supabase public client values only after the backend is deployed; test registration, email confirmation, password recovery, sync and permanent account deletion. CarPlay Audio and Video requests were submitted but approval is NOT confirmed. Check Apple’s response before enabling any CarPlay capability or choosing Info-CarPlay.plist; regenerate provisioning profiles only for granted entitlements. The custom desert dashboard is currently a phone preview, not arbitrary CarPlay wallpaper. Video browsing needs the current supported Apple SDK and vehicle APIs; do not bypass parked-only restrictions. Subscriptions remain disabled until App Store products and verified StoreKit flows are complete. Run tests, commit fixes to this GitHub repository, and report actual evidence. Do not submit a store release or claim App Review approval before the release checklist is complete. Use Rashed Saeed as legal developer; do not invent a company name.

## First commands

```sh
git clone https://github.com/azstudio971-lab/miznar-uae.git
cd miznar-uae
python3 scripts/generate_xcode.py
xcodebuild -project ios/WudCar.xcodeproj -scheme WudCar -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
open ios/WudCar.xcodeproj
```

The simulator build needs no signing. Physical devices/CarPlay require account access, approved capabilities and provisioning. Store certificates/private keys in the Mac keychain, never Git.
