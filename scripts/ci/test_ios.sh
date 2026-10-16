#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build/artifacts
swiftc ios/WudCar/Models/BrowserPolicy.swift tests/ios/main.swift -o build/browser-policy-tests
build/browser-policy-tests
device_id=$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
data = json.load(sys.stdin)["devices"]
runtimes = sorted(data, key=lambda k: [int(n) for n in re.findall(r"\d+", k)], reverse=True)
print(next(d["udid"] for runtime in runtimes for d in data[runtime] if "iPhone" in d["name"]))
')
# Complete first boot before XCTest starts its own launch timeout.
xcrun simctl boot "$device_id" || true
xcrun simctl bootstatus "$device_id" -b
xcodebuild -project ios/WudCar.xcodeproj -scheme WudCar \
  -destination "platform=iOS Simulator,id=$device_id" -configuration Debug \
  CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO \
  -resultBundlePath build/artifacts/WudCarBrowser.xcresult test \
  > build/artifacts/ios-tests.log 2>&1 || {
    tail -120 build/artifacts/ios-tests.log
    exit 1
  }
tail -25 build/artifacts/ios-tests.log
