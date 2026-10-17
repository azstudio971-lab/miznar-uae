#!/bin/bash
# Seed a real SwiftUI scene from the preceding phone release before installing the candidate.
set -euo pipefail
LEGACY_SHA=dac4b65b897cbd1db89abd7ff5634c4a5a1939b1
DEVICE=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(v["udid"] for a in d["devices"].values() for v in a if "iPhone" in v["name"]))')
echo "WUDCAR_TEST_DEVICE=$DEVICE" >> "$CM_ENV"
git fetch origin "$LEGACY_SHA"
mkdir -p /tmp/WudCarLegacy
git archive "$LEGACY_SHA" | tar -x -C /tmp/WudCarLegacy
(
  cd /tmp/WudCarLegacy
  xcodegen generate
)
xcodebuild -project /tmp/WudCarLegacy/WdCar.xcodeproj -scheme WdCar -sdk iphonesimulator -destination "platform=iOS Simulator,id=$DEVICE" -configuration Debug -derivedDataPath /tmp/WudCarLegacyBuild CODE_SIGNING_ALLOWED=NO build | tee /tmp/legacy-upgrade.log | xcpretty
xcrun simctl boot "$DEVICE" || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" /tmp/WudCarLegacyBuild/Build/Products/Debug-iphonesimulator/WdCar.app
xcrun simctl launch "$DEVICE" com.azstudio.wudcar
sleep 5
xcrun simctl terminate "$DEVICE" com.azstudio.wudcar || true
echo "OK: previous SwiftUI phone session installed; candidate UI tests must preserve and reopen it"
