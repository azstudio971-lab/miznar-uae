#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build/artifacts
xcodebuild -project ios/WudCar.xcodeproj -scheme WudCar \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -configuration Release -derivedDataPath build/simulator \
  CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build \
  > build/artifacts/simulator-build.log 2>&1 || {
    tail -100 build/artifacts/simulator-build.log
    exit 1
  }
ditto -c -k --sequesterRsrc --keepParent \
  build/simulator/Build/Products/Release-iphonesimulator/WudCar.app \
  build/artifacts/WudCar-iOS-Simulator.zip
python3 - <<'PY'
import hashlib, json, pathlib, plistlib, subprocess
app = pathlib.Path('build/simulator/Build/Products/Release-iphonesimulator/WudCar.app')
info = plistlib.loads((app / 'Info.plist').read_bytes())
archive = pathlib.Path('build/artifacts/WudCar-iOS-Simulator.zip')
manifest = {
    'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    'bundle_id': info['CFBundleIdentifier'],
    'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'],
    'sdk': info.get('DTSDKName'), 'platform': info.get('DTPlatformName'),
    'architecture': 'arm64', 'configuration': 'Release',
    'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
    'purpose': 'Native iPhone simulator preview. Not a CarPlay vehicle validation or installable device IPA.'
}
pathlib.Path('build/artifacts/preview-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps(manifest, indent=2))
PY
