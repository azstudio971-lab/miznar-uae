# WudCar 3.0.1 (4) verification checkpoint

Source builds on the existing release branch, including the VLC4 option, actual local HTTP HLS fixture, mounted video surface and QR fallback corrections. Build 4 prevents collision with in-flight build 3 attempts. No production merge or review submission.

Additional verified-in-code fixes awaiting native tests: connect the unchanged browser close callback to native templates; honor the phone auto-fullscreen preference in both player paths; keep AES-GCM-encrypted source cache available after first unlock for locked-phone CarPlay use, matching the existing device-only Keychain availability.

SubscriptionStore, SubscriptionView and WudCar.storekit remain unchanged. Existing eligible 3-day trial and AED24 monthly product only; all features included. No diagnostic UI or code imported from the test branch.

24 core browser files remain byte-identical to build17; 3 launch methods verbatim. Two scene-routing adapters are explicit exceptions. The full original 26-file diff is not empty.

Native test count, signed IPA capabilities, upload and internal availability remain pending. Physical vehicle, AirPlay/ReplayKit, real private servers, permission flows and Translation language models require owner testing. External subtitle overlays are phone-only; CarPlay search currently uses the iPhone fallback. No claim of complete historical test-suite success.
