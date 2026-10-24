import subprocess, pathlib, plistlib
BASE='6ca24bc877495dbaed55ff2aa833e687fa4e058f'
groups={
'WdCar/Shared':'WebEngine WebViewPool TabSession TabStore DesktopViewportView CarKeyboardBridge CarMouseBridge ShortcutCatalog ShortcutStore ShortcutArtwork SpeechDictation DrivingMonitor',
'WdCar/CarPlay':'CarBrowserViewController CarExternalDisplaySceneDelegate CarScreenLauncher CarVideoOverlay CarKeyboardView CarTextInputView CarShortcutsView CarTabsPanel BrowserChromeView CompactToolbarButton CarUI',
'WdCar/Phone':'PhoneBrowserScreen ShortcutsGridView TabsSwitcherView CarMousePadView PhoneCarKeyboardSheet'}
files=[f'{folder}/{name}.swift' for folder,names in groups.items() for name in names.split()]
for name in files+['Config/Info.plist','Config/WdCar.entitlements','WdCar/Phone/SubscriptionView.swift','WdCar/Shared/SubscriptionStore.swift','WdCarTests/WudCar.storekit','WdCarTests/SubscriptionTests.swift']:
 expected=subprocess.check_output(['git','show',f'{BASE}:{name}'])
 assert pathlib.Path(name).read_bytes()==expected, name+' differs from protected baseline'
settings='WdCar/App/Settings.swift'
expected=subprocess.check_output(['git','show',f'{BASE}:{settings}']).decode().replace('as? Bool ?? false','as? Bool ?? true',1)
assert pathlib.Path(settings).read_text()==expected
print('PASS: protected files except the owner-authorized build-16 external dashboard have empty diff; Info.plist and entitlements unchanged; Settings.swift differs only in default false → true.')

import re
project=pathlib.Path("project.yml").read_text()
baseline=subprocess.check_output(["git","show",f"{BASE}:project.yml"]).decode()
assert re.findall(r"^.*storeKitConfiguration:.*$",project,re.M)==re.findall(r"^.*storeKitConfiguration:.*$",baseline,re.M)
print("PASS: original SubscriptionTests and project.yml StoreKit configuration preserved.")

# Owner-authorized external dashboard repair for build 16; all other protected files stay exact.
import hashlib
assert hashlib.sha256(pathlib.Path('WdCar/CarPlay/CarDashboardViewController.swift').read_bytes()).hexdigest() == 'd9689c7600ae5c3fe604c76a8a31a0c19776b80e22ff2ca35aa5bb787cea3b54'
print('PASS: build-16 external dashboard matches the explicitly approved repair.')
