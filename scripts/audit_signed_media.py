#!/usr/bin/env python3
"""Audit a signed IPA on the macOS builder, without exposing profile contents."""
from pathlib import Path
import json, plistlib, subprocess, sys, tempfile, zipfile

ipa, mode = sys.argv[1:]
expected = {'Audio': {'com.apple.developer.carplay-audio'}, 'Video': {'com.apple.developer.carplay-video'}, 'Combined': {'com.apple.developer.carplay-audio', 'com.apple.developer.carplay-video'}}[mode]
with tempfile.TemporaryDirectory(prefix='wudcar-audit-') as temp:
    with zipfile.ZipFile(ipa) as archive:
        archive.extractall(temp)
    app = next((Path(temp) / 'Payload').glob('*.app'))
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    signed = plistlib.loads(subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(app)], stderr=subprocess.DEVNULL))
    profile = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i', str(app / 'embedded.mobileprovision')]))
    assert info['CFBundleIdentifier'] == 'com.azstudio.wudcar', 'Bundle identity mismatch'
    assert info['CFBundleShortVersionString'] == '2.2.2'
    assert int(info['CFBundleVersion']) >= 222
    assert signed['com.apple.developer.team-identifier'] == 'QS29RVJPUT'
    assert signed['application-identifier'] == 'QS29RVJPUT.com.azstudio.wudcar'
    actual = {k for k, v in signed.items() if k.startswith('com.apple.developer.carplay-') and v is True}
    assert actual == expected, f'Entitlement experiment mismatch: {actual}'
    for key in expected:
        assert profile['Entitlements'].get(key) is True, f'Provisioning profile missing {key}'
    report = {'bundle': info['CFBundleIdentifier'], 'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'], 'team': 'QS29RVJPUT', 'carplay_mode': mode, 'entitlements': sorted(actual), 'signed_audit': 'passed', 'physical_car_test': 'not established by this audit'}
    Path('build').mkdir(exist_ok=True)
    Path('build/media-signing-audit.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report))
