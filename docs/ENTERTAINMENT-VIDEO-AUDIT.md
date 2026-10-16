# Entertainment reference audit

The attached reference clip is approximately 222 seconds. Visual samples show Quick -> Browser, an address/search field, close/back/home controls, website shortcut tiles including YouTube, browsing/searching YouTube, video controls and fullscreen playback. The clip does not reveal all settings or bookmark editing, source code or entitlement approval.

## Phone development implementation
The development branch adds an in-app WKWebView, URL/search, back/forward/home/reload/close, shortcuts, saving the current page to favorites and editing custom links.
Search uses the multilingual system webSearch keyboard, with Arabic Unicode preserved through URLQueryItem. Website text fields use WebKit's native input behavior.
Users need their desired language enabled in iOS. This is not proof of Arabic keyboard availability on CarPlay.
No CarPlay browser, DLNA receiver, recent-history interface, local-file import or new release has been completed.

## Vehicle requirement
Provide Arabic and English input for Entertainment address/search and website search fields such as YouTube.
Verify available CarPlay keyboard languages and supported public APIs. Do not assume custom UIKit keyboards/extensions are supported on the car. Honor vehicle-reported keyboard restrictions.
Apple entitlement guidance and a supported browser route remain required before promising vehicle implementation.

## Validation
GitHub Actions simulator compilation is required. Physical browser login/playback/fullscreen and vehicle keyboard testing remain outstanding.
