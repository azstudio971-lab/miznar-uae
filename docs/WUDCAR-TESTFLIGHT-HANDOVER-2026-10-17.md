# WudCar — latest app delivery, 17 October 2026 (UAE)

## User-authorized goal
Use the attached WudCar.zip produced in Claude as the latest app source. Finish build preparation, build with Codemagic, sign for a separate app identity, upload to TestFlight, and make it installable on the owner's iPhone for physical CarPlay testing. User has no local Mac/Xcode requirement; cloud builds are intended. Preserve existing repository and previous app.

The user explicitly approved publishing the app source, logo and day/night intros to the existing public azstudio971-lab/miznar-uae repository. Use branch wudcar/testflight because wudcar conflicts with existing wudcar/* branches.

## App scope
- iPhone: Home, Entertainment browser/shortcuts, Xtream accounts, Settings; Arabic/English, appearance, privacy and terms.
- Official logo and day/night intros, iPhone startup only; light intro in light appearance, dark intro in dark appearance, skip/failure fallback.
- Xtream passwords in Keychain; connection test; live TV and movies currently implemented. Series not implemented in uploaded source.
- CarPlay: two tabs, Entertainment and Xtream; use official templates and Apple media playback. No navigation-template workaround for a web browser.
- Website shortcuts currently open on iPhone; AirPlay requires compatible content and a compatible vehicle. This is not an embedded CarPlay web browser.

## Identity and evidence
- Uploaded candidate Bundle ID: com.azstudio.wudcar; not yet verified/registered in Apple Developer.
- Existing historical App ID: com.azpixel.wudcar. Do not overwrite/revoke existing distribution assets.
- PR #4 remains draft and documents verified audio approval only, with video request pending at that time. The ZIP's video entitlement does not establish Apple approval.
- Verify current Apple capabilities and matching provisioning profile before signed delivery.

## Preparation completed
Imported latest source alongside existing repository files. Added unsigned Codemagic simulator workflow, strict shell failure handling, explicit CPTemplateApplicationScene in manifest, and valid missing brand color assets. Removed custom navigation-window CarPlay entry point. Original ZIP retained unchanged.

## Completion criteria
Successful simulator compilation; successful signed IPA build with matching entitlements; processed App Store Connect build; TestFlight access for owner; physical vehicle results recorded separately. Do not call delivery successful until evidence exists.
