import subprocess, pathlib, plistlib
BASE='6ca24bc877495dbaed55ff2aa833e687fa4e058f'
groups={
'WdCar/Shared':'WebEngine WebViewPool TabSession TabStore DesktopViewportView CarKeyboardBridge CarMouseBridge ShortcutCatalog ShortcutStore ShortcutArtwork SpeechDictation DrivingMonitor',
'WdCar/CarPlay':'CarBrowserViewController CarDashboardViewController CarExternalDisplaySceneDelegate CarScreenLauncher CarVideoOverlay CarKeyboardView CarTextInputView CarShortcutsView CarTabsPanel BrowserChromeView CompactToolbarButton CarUI',
'WdCar/Phone':'PhoneBrowserScreen ShortcutsGridView TabsSwitcherView CarMousePadView PhoneCarKeyboardSheet'}
files=[f'{folder}/{name}.swift' for folder,names in groups.items() for name in names.split()]
for name in files+['Config/Info.plist','Config/WdCar.entitlements','WdCar/Phone/SubscriptionView.swift','WdCar/Shared/SubscriptionStore.swift','WdCarTests/WudCar.storekit','WdCarTests/SubscriptionTests.swift']:
 expected=subprocess.check_output(['git','show',f'{BASE}:{name}'])
 assert pathlib.Path(name).read_bytes()==expected, name+' differs from protected baseline'
settings='WdCar/App/Settings.swift'
expected=subprocess.check_output(['git','show',f'{BASE}:{settings}']).decode().replace('as? Bool ?? false','as? Bool ?? true',1)
assert pathlib.Path(settings).read_text()==expected
print('PASS: protected files diff is empty; Info.plist and entitlements unchanged; Settings.swift differs only in default false → true.')

import re
project=pathlib.Path("project.yml").read_text()
baseline=subprocess.check_output(["git","show",f"{BASE}:project.yml"]).decode()
assert re.findall(r"^.*storeKitConfiguration:.*$",project,re.M)==re.findall(r"^.*storeKitConfiguration:.*$",baseline,re.M)
print("PASS: original SubscriptionTests and project.yml StoreKit configuration preserved.")
