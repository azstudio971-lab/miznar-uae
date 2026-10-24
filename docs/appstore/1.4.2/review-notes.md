# Review notes — draft only; NOT submitted

WudCar Media Player plays user-supplied video and audio, local files and authorized M3U/Xtream sources. No content is bundled or sold. The existing Premium subscription is unchanged and covers all features.

Both existing CarPlay entitlements are retained: com.apple.developer.carplay-audio and com.apple.developer.carplay-video. WWDC26 session 212 explains that video-only apps appear only in supported vehicles, while media suitable for video and audio may include both entitlements. Audio entitlement documentation explicitly allows combining them. This is a request for review of the implemented media use case, not a claim of entitlement approval.

Official references:
- https://developer.apple.com/videos/play/wwdc2026/212/
- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.carplay-audio

When the vehicle reports supportsVideoPlayback=false, playback configuration requests audio. Audio-only capability does not itself grant parked video support; video-only visibility requires a compatible car. Simulator and owner vehicle observations must be distinguished from universal behavior.

## Test source and steps
1. In M3U IPTV Player, import docs/appstore/1.4.2/sample.m3u (also available from the release branch raw file URL). This points to Big Buck Bunny, © 2008 Blender Foundation, CC BY 3.0, https://peach.blender.org/about/ . It is a legal sample, not an included TV service.
2. Open the sample group and play. Network availability must be verified during review.
3. Download the same MP4, import via Library → Add media → From Files; create a playlist.
4. Connect a supported CarPlay system and open Video Library. Choose the imported file or playlist. On audio-only systems verify Now Playing audio.
5. Verify skip interval and resume controls.

Entertainment offers an additional Web Player for passengers while parked. The existing GPS lock is enabled by default and covers video during motion when enabled. The user can disable this setting; therefore this draft does not claim an unconditional lock or blanket approval of arbitrary web views. The protected browser/display implementation is retained from build 17 and requires Apple's independent review.

No real-car test is claimed. No App Store submission or What to Test is authorized by this handover.
