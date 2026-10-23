# WudCar 3.0.1 (2) — owner feedback corrections

Base: 5da7464918de8deb885606b57d68d2dff8b0ea91, the source branch of installed3.0.1(1). Branch: fix/wudcar-3.0.1-build-2. Same app, bundle ID, signing and Audio+Video entitlements. No production merge, metadata upload or App Store review submission.

## Root cause and changes

1. The external-display scene unconditionally mounted the old CarDashboardViewController on every connection, independently of the new native CPTabBarTemplate. This could cover the native Library/TV/Favorites/Settings root. Ordinary media/external connections now create no custom window. Only an explicit browser request mounts the existing CarBrowserViewController. CarPlay connection and remote section selection dismiss that window and retain the native templates. Physical vehicle acceptance is pending; an external AirPlay session alone cannot manufacture a CPTemplateApplicationScene on an unsupported vehicle.
2. No concealed bypass of moving-car video restrictions was added. The phone preference applies to phone-only playback; video routed externally or requested for the connected car stays locked when movement is detected. Its footer now reads “اتبع ارشادات وقوانين المرور في بلدك”. The toggle label explicitly names iPhone video.
3. CarConnectionCard shows only CarPlay and Connected/Not connected. Removed browser details and Safari button. Connection toast is Connected, once per connection. Location explanation no longer opens automatically on connection; it follows the explicit motion-monitoring action in Cast/settings. GPS permission and safety fallback remain active.
4. Cast now operates on the current AVPlayer media item: prepares external playback, preserves queue/position, dismisses the browser window, requests native Now Playing, and uses the actual isExternalPlaybackActive signal for route status. Receiver selection stays with the official AVRoutePickerView. No browser launcher, bootstrap clip or fake mirroring is used by Cast. Native car video requires vehicle/AirPlay support; audio fallback is stated when unsupported. Removed the browser-opening button and duplicate passenger warning from Cast; app intro, terms and native CarPlay safety notices remain.

## Verification boundary

- 24 protected browser/core/input/catalog files remain byte-identical to build17. Original three browser template launch/configuration methods remain verbatim.
- Two scene-routing adapters are explicitly excluded from that gate for this requested correction: CarExternalDisplaySceneDelegate.swift and CarScreenLauncher.swift. This is not a claim that the full original26-file diff is empty.
- Six targeted native tests cover real external-scene connection without an old window, explicit browser activation/return, preserved connection state, mandatory car safety independent of the phone toggle, native tab order, Cast with no selected media, and native phone UI image captures.
- Tests/build/signing/upload pending at implementation checkpoint.
- No claim of physical CarPlay, AirPlay receiver discovery or successful vehicle video output. The owner performs that acceptance.

## Changed files

- WdCar/App/AppState.swift — Separate external route from browser presentation; concise connection state/toasts.
- WdCar/CarPlay/CarExternalDisplaySceneDelegate.swift — Avoid automatic legacy dashboard; explicit browser scene routing.
- WdCar/CarPlay/CarSceneDelegate.swift — Restore native templates on CarPlay connection.
- WdCar/CarPlay/CarScreenLauncher.swift — Reuse an existing route for an explicit browser request without a second bootstrap.
- WdCar/CarPlay/CarTemplateUI.swift — Return remote section navigation to native tabs and handle current-media Now Playing requests.
- WdCar/Media/PlayerHomeView.swift — Actual current-media Cast controls, real route status and library selection; concise Cast UI.
- WdCar/Phone/HomeView.swift — Connection card limited to connection status.
- WdCar/Phone/RootView.swift — Explicit location permission dialog title, rather than a connection warning.
- WdCar/Phone/SettingsView.swift — Requested traffic footer, clear phone-only toggle and immediate preference application.
- WdCar/Shared/DrivingMonitor.swift — Defer permission explanation until explicit user action.
- WdCar/Shared/PlaybackManager.swift — Preserve current media for Cast, publish actual external route state and enforce car safety.
- WdCarTests/Build2RoutingTests.swift — Targeted native routing, UI and safety regressions.
- project.yml — Build2, marketing version remains3.0.1.
- scripts/verify_frozen_browser.py — Explicit two-adapter exception; strict24-file core and three-method protection.
- codemagic.yaml — Dedicated gated build2 workflow; internal upload only, no What to Test or review submission.
- docs/verification/3.0.1-build-2/ — Scoped verification evidence and status.
