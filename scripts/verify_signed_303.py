#!/usr/bin/env python3
"""Inspect the actual signed app and both embedded extensions, not project entitlements."""
import pathlib, plistlib, subprocess, sys
root=pathlib.Path(sys.argv[1]); output=pathlib.Path('docs/verification/3.0.1-build-4'); output.mkdir(parents=True,exist_ok=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(root)],check=True)
group=['group.com.azstudio.wudcar']
platform={'application-identifier','com.apple.developer.team-identifier','get-task-allow','beta-reports-active','keychain-access-groups'}
required={'com.apple.developer.carplay-audio','com.apple.developer.carplay-video'}
expected={'com.azstudio.wudcar.ScreenRelay','com.azstudio.wudcar.CastWidget'}
seen=set()
for app in [root]+sorted((root/'PlugIns').glob('*.appex')):
    info=plistlib.loads((app/'Info.plist').read_bytes()); identifier=info['CFBundleIdentifier']
    assert info['CFBundleShortVersionString']=='3.0.1' and info['CFBundleVersion']=='4'
    assert isinstance(info.get('CFBundleName'),str) and info['CFBundleName'].strip()
    raw=subprocess.check_output(['codesign','-d','--entitlements',':-',str(app)],stderr=subprocess.DEVNULL)
    ent=plistlib.loads(raw)
    profile=plistlib.loads(subprocess.check_output(['security','cms','-D','-i',str(app/'embedded.mobileprovision')]))['Entitlements']
    assert ent.get('com.apple.security.application-groups')==group, f'{identifier}: missing signed App Group'
    assert set(group)<=set(profile.get('com.apple.security.application-groups',[])), f'{identifier}: profile missing App Group'
    assert ent.get('application-identifier')=='QS29RVJPUT.'+identifier
    assert ent.get('com.apple.developer.team-identifier')=='QS29RVJPUT'
    assert not ent.get('get-task-allow',False)
    allowed=platform|{'com.apple.security.application-groups'}
    if app==root:
        assert identifier=='com.azstudio.wudcar'
        for key in required: assert ent.get(key) is True and profile.get(key) is True
        allowed|=required
    else:
        assert identifier in expected; seen.add(identifier)
    assert not set(ent)-allowed, f'{identifier}: unexpected entitlements {set(ent)-allowed}'
    (output/(identifier+'-signed-entitlements.txt')).write_bytes(plistlib.dumps(ent))
    print('PASS signed capabilities:',identifier,sorted(ent)); print(raw.decode('utf-8'))
assert seen==expected, f'Missing embedded extensions: {expected-seen}'
