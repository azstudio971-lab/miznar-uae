# WudCar 1.5.0 — Development checkpoint, 21 October 2026

This is an incomplete development checkpoint, not a verified release or a claim that all requested features are finished.

## Source and isolation

- Existing repository: azstudio971-lab/miznar-uae.
- Base: wudcar-update14 at 6112677634c7da15be257e6082c04344cb6ed6e3.
- Development branch: develop/wudcar-1.5.0, now published with user authorization.
- Reviewed branch inventory and PRs 1–6. PRs 4–6 remain separate drafts and were not merged.
- Actual existing native identity is com.azstudio.wudcar; it was preserved, including the entitlement and signing files. Historical notes naming com.azpixel.wudcar were not applied.
- Marketing version: 1.5.0. Initial build: 15; Codemagic chooses max(15, latest TestFlight build + 1). In-app Settings displays only the marketing version.
- No production merge, production Netlify deploy, App Store review submission, or TestFlight upload was completed.
- User authorized development-branch publication in the follow-up. Git transport lacked credentials; the connected GitHub API published the verified repository branch. Production was not changed.

## Requested changes

| Area | Implemented source changes | Remaining verification / limitations |
| --- | --- | --- |
| Netflix S7351 | Inspected persistent shared WebKit store, macOS-style UA, media preferences, injected scripts and session handling. No DRM bypass or speculative DRM fix added. | Exact cause NOT established. No Netflix account/device playback test. Netflix's supported browser documentation does not establish support for this embedded iOS WKWebView/external-display combination. Changing UA cannot add DRM support. |
| Occasion logo | Bundled logo stays underneath a validated asynchronous PNG overlay; fixed URL, periodic refresh and foreground refresh, no cached image fallback after a failed refresh. Car home and square dark phone mark integrated. | Native success/404/offline/image-rejection tests not run. Daytime full wordmark intentionally keeps its different aspect ratio and has no square overlay. No live Netlify deployment. |
| Toolbar | Added 44pt native upper-left hotspot, ellipsis menu with toolbar/home actions, existing reveal and hide timing retained. | Native pointer/touch test added but not run. No vehicle knob test. Existing phone virtual pointer was not used as proof of official CarPlay input support. Custom external display is not established as an officially supported general CarPlay browser. |
| Desktop / fullscreen layout | Desktop preferredContentMode set on both phone and car at creation; YouTube desktop URL normalization now shared. Removed forced document root width/min-width and navigation-finish pageZoom reset; video overlay viewport variables retained. | No actual iPhone YouTube search/video/back/orientation test, therefore no CarPlay stage claimed. Desktop preference does not guarantee provider layout. Original user zoom settings retained. |
| Entertainment design | Responsive 1–5 column horizontal cards, dark gradient, lightweight diagonal pattern, subtle translucent card tint/highlight, borders, focus state, exact Arabic hint, centered layout when content fits. Rain.ae weather shortcut with native weather symbol. Existing shortcuts/editing remain. | Not visually verified in iOS. Approximation of reference, not a claim of near-final parity. Existing favicon loader retained; official wide brand wordmarks were not acquired/cleared. Existing model has no custom image field; extending it remains pending. Custom UIKit design is not established as a permitted CarPlay template. |
| M3U / Xtream | Both already use PlaybackManager. Retained shared pipeline and added observer cleanup, stale-item status guard, resource release/audio deactivation on stop, and phone close/dismiss cleanup. | Added repeated playback/stop regression with bundled video; not run. Real provider Xtream and M3U source tests on iPhone/car remain pending. |

## Occasion artwork contract

Reserved URL (not deployed by this checkpoint):

https://wudcar.netlify.app/branding/occasion.png

- PNG, exactly 512 × 512 pixels, up to 4 MB, preferably transparent RGBA.
- Preserve original canvas alignment; avoid stretching or adding opaque backgrounds unless deliberately covering the base.
- File source for an eventual full Netlify deploy: web/public/branding/occasion.png.
- Replace this file at the same path in the existing site's deployment to activate/change; omit/remove it in the next full site deployment to disable. Deploy the complete site, not a folder containing only this image.
- No image is included by default. Explicit missing-resource route prevents the SPA HTML fallback from posing as image content.
- App refreshes every five minutes while running and on foreground (minimum 30 seconds between requests). HTTP/image/network failure clears the overlay at completion and leaves the bundled base visible. NWPathMonitor clears the overlay when it reports loss of network connectivity. Failed refreshes also clear it.
- Netlify header requires revalidation. These config changes must be deployed before treating the URL as active.

## Tests and evidence

Passed locally:

- npm ci; npm run check: all 7 existing Node tests passed and Vite production build passed.
- python3 scripts/verify_logo.py: original daytime logo verified, 1145 × 1373, approved hash unchanged.
- Config plist parsing; extracted injected WebKit JavaScript passes node --check.
- git diff --check.

Added, NOT executed:

- Native desktop preference tests for phone/car.
- Native hotspot/menu test.
- Repeated shared player release test using bundled video, without claiming provider connectivity.

Unavailable locally: Xcode, iOS Simulator, attached iPhone and vehicle. The existing GitHub validation workflow incorrectly built the historical ios/WudCar project; it now targets the actual WdCar source via XcodeGen. Codemagic preview configuration now labels and retains 1.5.0 artifacts. GitHub Actions run 39567596212 passed both native iOS build and web checks/UI tests at 624f0d6. Run 39568223138 also passed both jobs at 77e32ea. Codemagic preview run 6ad874d2454d2506f7abbb3f started for the earlier checkpoint and is preparing an iOS 18.5 simulator; no test success is claimed yet. The development branch is not configured for automatic Codemagic publication.

## Official capability findings and release blockers

Apple's current WWDC26 guidance describes video browsing using CarPlay framework templates on supported vehicles, with video unavailability handled by the system. It does not establish the existing bootstrap-clip/external-display custom browser as an approved general browser path. That legacy source was retained rather than silently deleting existing functionality. No private API was introduced, but public APIs alone do not establish a permitted use case.

Official sources reviewed:

- https://developer.apple.com/videos/play/wwdc2026/212/ (video templates, supported vehicles and system input handling)
- https://developer.apple.com/carplay/
- https://developer.apple.com/documentation/webkit/wkwebpagepreferences
- https://developer.apple.com/documentation/webkit/wkwebview/pagezoom
- https://help.netflix.com/en/node/30081
- https://help.netflix.com/en/node/2090

Development-branch publication was authorized and completed. Production merge, production deployment and App Store submission remain separate. Before TestFlight, resolve official CarPlay-path scope and run native tests; then perform the required iPhone-first device tests before CarPlay. Do not call this release complete until these blockers and visual/provider tests are resolved.


## Final follow-up checkpoint

Development branch publication is complete. The independent Release150Tests suite passed all 5 tests at 65a1df2 in Actions run 39570854436 (desktop preferences, real-data layout captures, legacy/custom shortcut Codable compatibility, native hotspot/menu and exact-pixel artwork validation). The first run failed because its generated 512-point image used Retina scaling; the test now explicitly produces and asserts a 512-pixel PNG. Existing optional custom image URLs are now supported in the model/editor and car/phone cards. Offline detection now clears the occasion overlay via NWPathMonitor.

Signed WudCar 1.5.0 (15), built from b84a4b0, uploaded successfully in Codemagic build 6ad8798b454d2506f7abbcbd. Apple processing completed; the build is associated with the existing WudCar Internal group (one tester). No external beta group or App Store review submission was added. Later changes through 65a1df2 affect tests only. The earlier Codemagic full-suite preview was canceled and is not a successful test.

See WUDCAR-1.5.0-AR.md for the current authoritative status, screenshots and actual-device test requirements. The scoped 5-test pass is not a pass for the full StoreKit/M3U/Xtream/provider/device suite. Netflix and official custom CarPlay browser support remain unresolved. Native snapshots currently show letter fallbacks while favicons are unavailable/not yet loaded; visual parity and official wide brand wordmarks are not complete.
