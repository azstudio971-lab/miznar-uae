# WudCar — Cloud Mac recovery record

Updated: 2026-10-10.

## Project

- Repository: azstudio971-lab/miznar-uae; default branch main.
- Open ios/WudCar.xcodeproj.
- App version 1.1.1; build 111; iOS minimum 17.0.
- Bundle identifier: com.azpixel.wudcar.
- Apple Developer Team ID: QS29RVJPUT; team display name Rashed Saeed.
- Cloud machine: MacinCloud AS442, macOS host AS442-I.
- Xcode 26.6; iPhone 17 Pro simulator on iOS 26.5.
- Environment configuration is in ios/Config.xcconfig. Local overrides belong in ignored ios/Local.xcconfig.

## Verified work

- Signed into the developer team in Xcode.
- Simulator build succeeded and application launched. Home, library, settings and Arabic layout were inspected.
- Theme thumbnail overflow reproduced and fixed in PR #3, merged as 81f9dce21ab29873272b91eff56c41e4371cfb3e. GitHub Actions run 38044211991 passed.
- Apple Development certificate AS442-I appeared in Xcode, created 2026-10-10.
- Apple Distribution certificate appeared in Xcode, creator Rashed Saeed, created 2026-10-10; Apple certificate ID 822CP9LCL3, expiration 2027-10-10.
- App Store provisioning profile WudCar App Store 2026-10-10 created; Apple profile ID Y5M4Q4FP52, bundle com.azpixel.wudcar, expiration 2027-10-10.

## Outstanding work

- Local cloud checkout still needs verification against the merged theme fix; Xcode reported local changes during pull and a stash workflow was used. Preserve local changes and inspect them before resolving anything.
- Archive attempt failed because automatic development signing could not generate a provisioning profile with zero registered devices. The chosen next path is manual App Store distribution signing for TestFlight, without a USB connection to the cloud machine.
- The distribution certificate export password dialog is prepared. Export is not yet confirmed complete.
- Download/select the created App Store distribution provisioning profile in Xcode, archive, validate and upload to App Store Connect.
- TestFlight invitation is not yet issued; external testing may require Apple beta review.
- APNs credentials, physical notification delivery, CarPlay approval and StoreKit production setup remain unverified. See RELEASE-1.1.1.md.

## Backup and restore

Source and nonsecret settings are stored here. A certificate private key is a separate credential, not source code. Keep an encrypted signing export in owner-controlled secure storage and its password in a password manager. Do not commit Apple passwords, p8/p12 private keys, or backend secret keys in plaintext.

To restore on another Mac: clone the repository, install Xcode and iOS runtime, sign into the same developer team, import the encrypted signing export into Keychain using its password, download the matching provisioning profile, then open the project and build. Download the export from the cloud Mac before ending or deleting that environment. An encrypted export remaining only on AS442 is not an off-machine backup.
