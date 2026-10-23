#!/usr/bin/env python3
import plistlib, subprocess
from pathlib import Path
base='6ca24bc877495dbaed55ff2aa833e687fa4e058f'
subscription=['WdCar/Shared/SubscriptionStore.swift','WdCar/Phone/SubscriptionView.swift','WdCarTests/WudCar.storekit']
diff=subprocess.check_output(['git','diff',base,'--',*subscription],text=True)
assert not diff, 'Subscription implementation or product changed'
assert not Path('WdCar/Resources/access-policy.json').exists(), 'New feature usage limits are not authorized'
info=plistlib.loads(Path('Config/Info.plist').read_bytes())
allowed={'NSCameraUsageDescription','NSLocalNetworkUsageDescription','NSMicrophoneUsageDescription','NSSpeechRecognitionUsageDescription','NSLocationWhenInUseUsageDescription'}
usage={key for key in info if key.endswith('UsageDescription')}
assert usage<=allowed, f'Unexpected permissions: {usage-allowed}'
for key in ['NSBonjourServices','NSPhotoLibraryUsageDescription','NSUserTrackingUsageDescription']: assert key not in info
assert info['NSSupportsLiveActivities'] is True
capabilities=plistlib.loads(Path('Config/WdCar.entitlements').read_bytes())
assert set(capabilities)=={'com.apple.developer.carplay-audio','com.apple.developer.carplay-video','com.apple.security.application-groups'}
assert capabilities['com.apple.security.application-groups']==['group.com.azstudio.wudcar']
for name in ['ScreenRelay','CastWidget']:
    ent=plistlib.loads(Path(f'Extensions/{name}/{name}.entitlements').read_bytes())
    assert ent=={'com.apple.security.application-groups':['group.com.azstudio.wudcar']}
print('PASS: unchanged subscription, authorized privacy keys, exact source entitlement allowlist')
