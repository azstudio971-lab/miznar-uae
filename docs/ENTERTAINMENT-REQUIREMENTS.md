# WudCar Entertainment requirements

The user reports successfully using APTV's browser and a YouTube favorite on their iPhone connected to their car. Treat this as evidence of operation on that setup, not proof of its internal implementation or transferable Apple permission.

## Required experience
The required primary Entertainment experience is inside the CarPlay app. The iPhone app organizes the library, favorites, URL shortcuts and settings; an iPhone web browser alone does not satisfy this requirement. The CarPlay browser/video experience remains contingent on Apple's permission and a supported public API.
- Browse: URL entry, website shortcuts including YouTube, back, forward, reload, loading/error state, and full-screen video where supported.
- Favorites: add/edit/remove website or media favorites; open the same saved YouTube destination in the browser; share favorites between phone and car.
- Recents: recently visited sources and played media; resume where the media provider supports it.
- Library: authorized M3U/M3U8 sources, HLS streams, direct video URLs, and imported local videos. Websites must remain distinguished from direct playable streams.
- Playback: play/pause, seek where supported, previous/next library item, aspect ratio and fit controls, and supported quality choices.
- Phone control: prepare library/settings before connecting; shared playback preferences and favorites.
- Casting: investigate DLNA reception as a separate feature from Apple's official AirPlay-based CarPlay video route. Do not assume DLNA grants permission to render arbitrary video on CarPlay.
- Vehicle operation: appropriate focus navigation for touch/knobs; honor official vehicle-reported video availability. Parked video is a product requirement.

## Evidence and open details
Developer documentation confirms channels/favorites/recents/quick/casting/configuration sections, phone remote playback, shared settings, local videos, and DLNA reception.
Browser/YouTube behavior on the user's setup is user-tested. A supplied reference video has been sampled and confirms Quick > Browser, website tiles, URL/search entry and YouTube playback. It does not establish every configuration option, vehicle-reported parked state, or Apple's authorization. Arabic and English input on the CarPlay search field is a required investigation; do not promise a custom vehicle keyboard before API verification.
Do not claim all websites or protected services work. Do not copy proprietary source, branding, or assets.
Apple's exact approval for APTV is not publicly established. WudCar's video request receipt was observed, approval is outstanding.
No implementation is completed by this requirements document.

## Needed for faithful validation
Record the APTV version, iOS version, vehicle/head-unit model, and the visible flow:
launch APTV on CarPlay -> Entertainment/Quick -> browser -> favorites -> YouTube -> playback -> fullscreen -> back -> settings.
Record only while parked; conceal personal accounts and notifications.

## Source
https://aptv.app/carplay
