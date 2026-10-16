# WudCar: browser-first V3 slice

Updated 2026-10-16 (Asia/Dubai). Internal V3, build 113. Public name remains WudCar / وُد كار.

## الحالة بالعربي

نُفذت أول نسخة لمتصفح الآيفون داخل «الترفيه ← المتصفح»، باستخدام WebKit / WKWebView وواجهة SwiftUI خاصة بود كار. البداية يوتيوب وتيك توك فقط. يتضمن المتصفح شريط عنوان/بحث، رجوع وتقدم وتحديث، حتى 8 تبويبات، حفظ وتعديل وحذف اختصارات، تغيير حجم الصفحة، عرض الجوال/سطح المكتب، ومظهر عربي/إنجليزي نهاري/ليلي.

**متصفح CarPlay الكامل المطلوب لم يُنفذ.** لا يصح اعتبار متصفح الهاتف أو قالب قائمة روابط أو AirPlay بديلًا مكتملًا له. واجهة CarPlay في هذا الفرع تُظهر الحالة غير المتاحة بصدق. لم يتم رفع TestFlight أو تعديل حساب Apple أو ملفات التوقيع في البوابة.

## Reference analysis: what the supplied images establish

| Image | Observed behavior | Technical conclusion |
| --- | --- | --- |
| IMG_0835(1).jpeg | CarPlay side dock and app tabs | Native CarPlay context is visible; exact head-unit OS/version is not shown. |
| IMG_0834(1).jpeg | Site icon grid and address/search toolbar | Custom browser chrome, not evidence of a named Apple browser template. |
| IMG_0837.jpeg | Two tab thumbnails, plus/close controls, 2 / 8 | Tab switcher with an apparent eight-tab limit. |
| IMG_0838(1).jpeg | youtube.com inside the same toolbar | Embedded website navigation, not only a shortcut launcher. |
| IMG_0839(1).jpeg | Arabic floating keyboard, including Ctrl + Alt | Desktop-like/custom input presentation; it does not identify UIKit, WebKit, Windows or Android as its implementation. |
| IMG_0841.jpeg | YouTube content and video area | Website layout and playback surface visible. |
| IMG_0842.jpeg | Fullscreen video with progress/time | A playing video is depicted; the still image does not prove uninterrupted playback, route type or underlying player class. |
| IMG_0843(1).png | iPhone Explore offers Browser, mirroring and casting separately | These are separate functions, not proof that the browser is just screen mirroring. |
| IMG_0844(1).png | iPhone site grid, tabs counter, bottom address field | In-app browser with a custom start page. |
| IMG_0845(1).png | Zoom 100%, save, request mobile website, home | Page zoom, shortcuts and content-mode controls. |

The supplied images were inspected directly in the conversation. Their originals are not published to this public repository. They establish the reference UI, but do not reveal source code, private/public API use, entitlements, exact browser engine, keyboard library or OS version. WKWebView is our implementation choice for iPhone, not a verified claim about CarTV internals. The screenshots do not prove Chromium, SafariViewController, or a named CarPlay web template.

## Repository continuity and PR #4 review

- Started from existing `feature/wudcar-v3-video` at `328fd93`; continued in `feature/wudcar-v3-browser`.
- Inspected PR #4 (`3e38337`): open draft, with phone WebKit scaffolding, explicit CarPlay scene registration, and an Audio-entitled three-tab car UI. It is not the requested V3 browser and was not merged into main.
- Merged `main` at `6622ec6` into this work branch to preserve both approved iPhone intro videos. No intro playback changes in this browser-only phase.
- Preserved existing four phone sections and secure Xtream account form. No new IPTV playback, subscriptions or pricing.
- Kept Bundle ID, team and public branding. The previous Audio car implementation remains recoverable in its existing branch/history.

## Implemented phone behavior

- Entertainment contains a Browser entry. Opening it shows the start page, without immediately loading a third-party site.
- YouTube and TikTok are bundled defaults with local icons; no favicon tracking service. Untouched generated Shahid default migrates away; edited and user-created sources survive.
- `WKWebView` displays real websites, not an iframe or HTML imitation. HTTPS URLs and bare domains are normalized; search text, including Arabic, is encoded using URLComponents.
- Reject executable/file/custom-app schemes and credential-bearing addresses. Navigation and popup requests receive the same policy. Invalid page URLs never become media URLs handed to AVPlayer.
- Up to eight WebKit tabs. `target=_blank` receives a real new WKWebView using the configuration supplied by WebKit (preserves opener/request semantics). Tabs stay in memory during the app session, including closing/reopening the browser. Tab history and snapshots are not written to disk.
- URL, title, navigation availability, loading and progress are observed, including single-page website changes. Thumbnails are local, in-memory snapshots.
- Home, close and switching tabs pause/suspend hidden media. Returning to a tab permits playback without forcing autoplay.
- Persistent WebKit website store for site sessions; user can clear website data/tabs from Settings. No cookies or website credentials are sent to WudCar services. Existing shortcut records use existing local persistence.
- Native iPhone keyboard (Arabic/English according to the device), native WebKit inline/fullscreen playback and supported AirPlay media capability. This does not promise provider login, DRM compatibility, AirPlay availability or actual playback on every service.
- Source edits and optional HTTPS icon images use the existing editor. Photo import is deferred.

## CarPlay findings and unresolved requirement

Read the Apple CarPlay Developer Guide dated **2026-10-13**, particularly printed pages 8, 14, 15 and 25:

- Video apps use the Video entitlement and must support AirPlay video streaming.
- The Video entitlement's minimum iOS version is 27. Phone WKWebView support does not require iOS 27; the phone target remains iOS 17+.
- Listed Audio/Video templates include lists, grids, tab bars, now playing and (iOS 27+) search/voice control. No general web-view template is documented. Search is a system keyboard plus result list, not a freeform keyboard over a website.
- Unsupported templates cause runtime exceptions. We do not abuse a map/navigation entitlement, install WKWebView into a CarPlay window, invoke private selectors, or bypass vehicle restrictions.
- The newer guide/account instruction and general WWDC/entitlement web page differ on combining Audio/Video. This branch follows the account's recorded direction: **Video only**.

The generator, entitlement file and example now agree on `com.apple.developer.carplay-video`. This is a source configuration only: it does not enable the capability on the App ID, renew a profile, establish car support, or make websites available in CarPlay. The car scene is an explicit unavailable-state shell with the approved two labels, Entertainment and TV. No enabled YouTube/TikTok car buttons falsely claim to open the websites.

**Release blocker:** identify and validate a supported vehicle-display web browsing path with the actual SDK, a suitable video-capable car/simulator and signing profile. CarTV's App Store presence and screenshots do not identify that path. Do not merge/deploy this as a completed CarPlay release. Do not silently replace the requested browser with mirroring or phone-only actions.

## Validation and running

Local environment is Linux, without Xcode. `npm run check` passed (7 existing tests plus web build). Native build and automated simulator UI tests are run by GitHub Actions; consult the PR checks for the latest result rather than inheriting PR #4's old success.

```
python3 scripts/generate_xcode.py
swiftc ios/WudCar/Models/BrowserPolicy.swift tests/ios/main.swift -o /tmp/wudcar-browser-tests
/tmp/wudcar-browser-tests
xcodebuild -project ios/WudCar.xcodeproj -scheme WudCar \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO test
```

UI tests cover the starter pair, eight-tab cap, reopening the browser, unsafe URL rejection, saving a shortcut, actual WebKit navigation/back/popup/home using offline test pages, and Arabic/light rendering. Test fixtures are compiled only in DEBUG and registered only under explicit UI-test launch arguments. They do not impersonate YouTube/TikTok or count as provider playback tests. Workflow artifacts retain the native test result bundle and screenshot attachments.

Still needs a real device/provider pass: YouTube and TikTok opening, login if needed, user-initiated playback, fullscreen exit, orientation, keyboard, consent/popups, offline recovery, and stopping hidden-tab playback. No physical-device/car pass or signed archive is claimed.

## Sources

- Apple CarPlay: https://developer.apple.com/carplay/
- Apple guide: https://developer.apple.com/download/files/CarPlay-Developer-Guide.pdf
- WWDC26 session 212: https://developer.apple.com/videos/play/wwdc2026/212/
- WKWebView: https://developer.apple.com/documentation/webkit/wkwebview
- Video entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.carplay-video
- CarTV developer site (marketing claims, not source inspection): https://cartv.app/
