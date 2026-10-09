# Apple release checklist and review notes draft

Developer: **Rashed Saeed**, Individual. App: WudCar. Bundle: com.azpixel.wudcar. Team: QS29RVJPUT.

## Reviewer notes — draft, update before submission

WudCar is a bilingual personal media companion. Guest mode offers local preferences, theme previews and user-provided audio/video sources. The app does not bundle third-party channels, download subscription content, bypass DRM, or sell access to external media. Optional email accounts synchronize preferences. Permanent account deletion is in Settings → Account and requires a confirmation, not a support ticket. Apple subscriptions, if introduced, must be managed separately from account deletion.

The “Spirit of the UAE” scene is an in-phone preview. CarPlay uses Apple's permitted templates. Do not advertise arbitrary CarPlay wallpaper replacement. Audio/Video entitlement requests are pending; remove claims of availability until capabilities and vehicle support are verified. No push notifications are requested in this build.

## Before sending for review

- Provide stable public HTTPS privacy, terms, support and account-deletion URLs.
- Provide working reviewer credentials if cloud-only features require access; create them outside this public repository. Keep backend operational during review.
- Remove unavailable release-only screens or clearly scope what the submitted build supports. Development status messages are not a finished store experience.
- Verify every marketed feature on hardware; no broken placeholders, unsupported external links or nonfunctional purchase buttons.
- For digital subscriptions, use Apple IAP, show localized product price/period and any eligibility-based trial terms, restore/manage actions, privacy/terms links and cancellation details. Do not enable the planned prices until actual products exist.
- Match data disclosures to collection: optional name/email/account identifier/city/preferences; no tracking or advertising currently. Review hosting/Auth log retention with actual providers.
- Keychain contains session tokens. Local files contain preferences/imported user media. No API secret keys, certificates or reviewer passwords are committed.
- Validate localization, RTL, Dynamic Type, VoiceOver, loading/empty/error states, offline fallback and deletion failures.
- Explain Audio and Video category eligibility accurately. Do not misrepresent a clock/theme dashboard as a valid Audio category use case. Confirm media app functionality meets category requirements.
- Video use in a vehicle must follow system availability and parked restrictions; never invent a local speed check as a substitute for Apple's system behavior.
- Audit uploads and content rights. The owner is responsible for licensed theme/audio content.
- Complete the App Store Connect age rating, export compliance and privacy questionnaire truthfully based on final binary.

No document or implementation here guarantees App Review acceptance.
