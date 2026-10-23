#!/usr/bin/env python3
"""Static release invariants. This is not an iOS compile or device test."""
from pathlib import Path
import plistlib

root = Path(__file__).resolve().parents[1]
project = (root / 'project.yml').read_text()
assert 'MARKETING_VERSION: "2.2.2"' in project
assert 'PRODUCT_BUNDLE_IDENTIFIER: com.azpixel.wudcar' in project
assert 'DEVELOPMENT_TEAM: "QS29RVJPUT"' in project
assert plistlib.loads((root / 'Config/WdCar.entitlements').read_bytes()) == {'com.apple.developer.carplay-audio': True}
launcher = (root / 'WdCar/CarPlay/CarScreenLauncher.swift').read_text()
assert 'intro_night' not in launcher
assert 'PlaybackManager.shared.play' not in launcher
for path in (root / 'Config').glob('*.plist'):
    plistlib.loads(path.read_bytes())
print('Static identity, entitlement, plist and bootstrap checks passed; device tests remain separate.')
