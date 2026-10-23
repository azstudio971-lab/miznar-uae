#!/usr/bin/env python3
import plistlib,sys
from pathlib import Path
app=plistlib.loads(Path(sys.argv[1]).read_bytes())
profile=plistlib.loads(Path(sys.argv[2]).read_bytes())['Entitlements']
for key in ['com.apple.developer.carplay-audio','com.apple.developer.carplay-video']:
    assert app.get(key) is True, f'Signed app must have {key}=true'
    assert profile.get(key) is True, f'Profile must allow {key}=true'
assert app.get('application-identifier')=='QS29RVJPUT.com.azstudio.wudcar'
assert app.get('com.apple.developer.team-identifier')=='QS29RVJPUT'
assert app.get('get-task-allow',False) is False
out=Path('docs/verification/3.0.1');out.mkdir(parents=True,exist_ok=True)
(out/'signed-entitlements.txt').write_bytes(plistlib.dumps(app))
print('PASS: both signed CarPlay entitlements, existing Bundle ID and team, distribution signing')
