# WudCar 1.6.0 — Build 17

Development branch: `develop/wudcar-build-17`. Based on stable TestFlight 1.6.0 (16); marketing version remains 1.6.0. Existing bundle `com.azstudio.wudcar`, signing and entitlements are preserved. The requested `com.azpixel.wudcar` differs from the actual installed project identifier; changing identity would not update the existing app, so no identifier change was made.

## Scope

Only entertainment shortcut presentation/catalog and top toolbar icon presentation changed. WebEngine, desktop viewport, UA, loading/navigation, fullscreen, player, M3U/Xtream, mouse controls, home, branding, subscriptions and backend remain unchanged.

- Cards use 1.55:1 horizontal rectangles with uniform sizing, brand colors, subtle depth, dark navy gradient and lightweight geometric pattern.
- 8 columns where an available wide view supports minimum 104pt card width (e.g. 960×480, 1280×480); 5 on suitable square views (640×640). Smaller displays adapt without horizontal scrolling. Vertical scrolling exposes all sites and favorites.
- The 29 requested default sites appear in exact order. Existing functional paths for TOD, SoundCloud, Alawi TV, Windows XP and Outlook are retained. Apple TV is 14, Radio Garden 15. No Abu Dhabi-specific shortcut is added.
- Only exact legacy seed fingerprints are eligible for removing obsolete defaults. Custom/edited records retain IDs, links, artwork and colors; matching customized paths take precedence over a generic seed URL. Original encoded data is retained under `wd.shortcuts.pre17`, with one-time migration `wd.shortcuts.catalog17`. No later launch re-adds a user-deleted site.
- 25 official website/developer icons are bundled (source manifest `SHORTCUT-ICON-SOURCES-17.json`); Higher-resolution YouTube Kids, TikTok and Twitch icons use verified developer artwork from Apple’s public catalog; Google and Spotify were also upgraded. Remaining entries retain network-favicon lookup and visual fallback. Weather uses the existing native sun/cloud icon. The Alawi favicon is the real site icon; generated lettering from the reference image is not represented as an official logo.
- The compact 20pt toolbar now contains explicit 12×12pt symbol views with padding and centered alignment, independent of UIButton's previous configured image sizing. Existing 44pt button widths and expanded touch regions remain. Tabs retain their count; actions and hide/reveal timing are unchanged.

## Verification

Codemagic signed build `6ad9c9818a524d15d6a5f13d`, source `7f6b180c971a371485929f12c84c04ebddc736ac`: 8 tests passed, 0 failures, 0 skips, 90.704s. Release17 tests passed in 17.284s; live YouTube desktop phone-before-car-controller probe passed in 60.478s, both viewport widths 1280 and pageZoom 1.0, stable channel navigation/back. Screenshots reviewed at 1280×480, 960×480 and 640×640, plus automated geometry assertions at 640×360 and 320×240.

The first verification run failed only the test's square-glyph assumption: SF Symbol alignment rects naturally give different rendered heights (6.67–13pt) despite a uniform layout box. The production code did not need to stretch symbols. The corrected test retains the actual containment/padding/centering checks, verifies bounds at most 14pt and tests actual Arabic/English settings; all pass.

Signed 1.6.0 (17) archive built successfully with existing identity and CarPlay entitlements. Apple upload succeeded with no errors, delivery UUID `db5595f1-0756-49a5-9a68-36342143c9e5`. Apple processing completed. Internal group WudCar Internal now contains 1.6.0 (17), status Testing, 1 tester, 90-day expiry. Owner can install the update through TestFlight. No What to Test or change description was added. GitHub run `39748131261` also passed: all 13 native tests, 0 failures, in 155.026s; web checks/build/UI tests passed. Final native screenshots were downloaded and reviewed from artifact `12412364893`, source `7f6b180c971a371485929f12c84c04ebddc736ac`.

Tests cover catalog order, lossless migration and customized paths, card proportions/columns/no horizontal overflow, favorite addition/activation, toolbar symbol containment and both layout directions, plus existing 1.5/1.6 regressions and live YouTube desktop navigation.

The environment uses an iPhone simulator and a car controller hosted at car-sized dimensions. Physical CarPlay inputs and authenticated/DRM playback for every service cannot be certified here. Opening a page or loading a site icon is not proof of video playback. No DRM bypass or browser behavior changes are included.

## Delivery authorization

Owner explicitly requested complete testing and TestFlight upload for personal testing, and asked that no change description be added there. Upload via manual Codemagic device-validation workflow only, no App Store submission and no production merge. TestFlight What to Test/release notes are left untouched.


## Final evidence

- Native wide grid: `verification/17/17-grid-1280x480.png`.
- Native square grid: `verification/17/17-grid-640x640.png`.
- Native compact toolbar: `verification/17/17-toolbar-3-960x480.png`.
- TestFlight availability: `verification/17/testflight-1.6.0-17-testing.jpg`.
- Filtered final test log: `verification/17/RESULTS.txt`.

The native screenshots are simulator output, not physical CarPlay photographs. The black upper safe area in the car-controller capture comes from hosting in an iPhone simulator. All app changes are confined to the requested catalog/card presentation and toolbar symbol containment. Production branches and release approval remain untouched.
