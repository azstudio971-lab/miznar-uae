#!/bin/bash
# Current 26.6 runtime rejects SKTestSession with notEntitled. Use a real 18.5 runtime, not a subscription bypass.
set -euo pipefail
find_device() {
  xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); ids=[v["udid"] for k,a in d["devices"].items() for v in a if "iOS-18-5" in k and "iPhone" in v["name"]]; print(ids[0] if ids else "")'
}
DEVICE=$(find_device)
if [ -z "$DEVICE" ]; then
  xcodebuild -downloadPlatform iOS -buildVersion 18.5 >&2
  DEVICE=$(find_device)
fi
if [ -z "$DEVICE" ]; then
  DEVICE=$(xcrun simctl create WudCar301StoreKit com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro com.apple.CoreSimulator.SimRuntime.iOS-18-5)
fi
xcrun simctl boot "$DEVICE" >&2 || true
xcrun simctl bootstatus "$DEVICE" -b >&2
printf '%s\n' "$DEVICE"
