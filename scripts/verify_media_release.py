#!/usr/bin/env python3
"""Static release invariants. This is not an iOS compile or device test."""
from pathlib import Path
import plistlib, hashlib, json, os

root = Path(__file__).resolve().parents[1]
project = (root / 'project.yml').read_text()
assert 'MARKETING_VERSION: "2.2.2"' in project
assert 'PRODUCT_BUNDLE_IDENTIFIER: com.azstudio.wudcar' in project
assert 'DEVELOPMENT_TEAM: "QS29RVJPUT"' in project
mode = os.environ.get('CARPLAY_MODE', 'Combined')
expected = {
    'Audio': {'com.apple.developer.carplay-audio': True},
    'Video': {'com.apple.developer.carplay-video': True},
    'Combined': {'com.apple.developer.carplay-audio': True, 'com.apple.developer.carplay-video': True},
}[mode]
assert plistlib.loads((root / 'Config/WdCar.entitlements').read_bytes()) == expected
print(f'CarPlay entitlement configuration verified: {mode}')
launcher = (root / 'WdCar/CarPlay/CarScreenLauncher.swift').read_text()
assert 'intro_night' not in launcher
assert 'PlaybackManager.shared.play' not in launcher
for path in (root / 'Config').glob('*.plist'):
    plistlib.loads(path.read_bytes())
print('Static identity, entitlement, plist and bootstrap checks passed; device tests remain separate.')

for name, expected in json.loads((root / 'docs/releases/2.2.2/preserved-source.json').read_text()).items():
    content = (root / name).read_bytes()
    actual = hashlib.sha1(b'blob ' + str(len(content)).encode() + b'\0' + content).hexdigest()
    assert actual == expected, f'Protected browser/subscription/branding source changed: {name}'
print('Protected browser, shortcuts, subscription, intro and mouse sources match build 17.')
