#!/usr/bin/env python3
"""Release gate: the owner's browser baseline is immutable."""
import subprocess
from pathlib import Path
BASE = '6ca24bc877495dbaed55ff2aa833e687fa4e058f'
PATHS = [
'WdCar/Shared/WebEngine.swift', 'WdCar/Shared/WebViewPool.swift',
'WdCar/Shared/TabSession.swift', 'WdCar/Shared/TabStore.swift',
'WdCar/CarPlay/CarBrowserViewController.swift', 'WdCar/CarPlay/CarDashboardViewController.swift',
'WdCar/CarPlay/CarExternalDisplaySceneDelegate.swift', 'WdCar/CarPlay/CarScreenLauncher.swift',
'WdCar/Phone/CarMousePadView.swift','WdCar/Phone/PhoneBrowserScreen.swift',
'WdCar/Shared/CarMouseBridge.swift', 'WdCar/Shared/CarKeyboardBridge.swift',
'WdCar/CarPlay/CarKeyboardView.swift','WdCar/CarPlay/CarTextInputView.swift',
'WdCar/Phone/PhoneCarKeyboardSheet.swift','WdCar/Shared/SpeechDictation.swift',
'WdCar/Shared/ShortcutCatalog.swift','WdCar/Shared/ShortcutStore.swift','WdCar/Shared/ShortcutArtwork.swift',
'WdCar/Phone/ShortcutsGridView.swift','WdCar/CarPlay/CarShortcutsView.swift',
'WdCar/CarPlay/BrowserChromeView.swift','WdCar/CarPlay/CompactToolbarButton.swift',
'WdCar/CarPlay/CarTabsPanel.swift','WdCar/Phone/TabsSwitcherView.swift','WdCar/Shared/DesktopViewportView.swift']
# Build 2: the owner reported that automatic external-window routing covered
# the native media tabs. Only these routing adapters are authorized to change;
# WebKit, the browser controller, input, catalog and desktop behavior stay frozen.
ROUTING_EXCEPTIONS = {
'WdCar/CarPlay/CarExternalDisplaySceneDelegate.swift',
'WdCar/CarPlay/CarScreenLauncher.swift',
}
CORE_PATHS = [path for path in PATHS if path not in ROUTING_EXCEPTIONS]
for path in CORE_PATHS:
    before = subprocess.check_output(['git','show',f'{BASE}:{path}'])
    assert before == Path(path).read_bytes(), f'FROZEN BROWSER CHANGED: {path}'
# Also preserve the three original launch/configuration methods verbatim.
def method(text, name):
    start = text.index('    private func '+name+'(')
    brace = text.index('{',start); depth=1; end=brace+1
    while depth:
        depth += (text[end]=='{') - (text[end]=='}'); end+=1
    return text[start:end]
path='WdCar/CarPlay/CarTemplateUI.swift'
before=subprocess.check_output(['git','show',f'{BASE}:{path}'],text=True)
after=Path(path).read_text()
for name in ['carScreenItem','startCarScreen','applyPlaybackConfiguration']:
    assert method(before,name)==method(after,name), f'LAUNCH METHOD CHANGED: {name}'
report=Path('docs/verification/3.0.1-build-3');report.mkdir(parents=True,exist_ok=True)
stat=subprocess.check_output(['git','diff','--stat',BASE,'--',*CORE_PATHS],text=True)
assert not stat,stat
(report/'browser-diff-stat.txt').write_text(stat)
(report/'browser-files.txt').write_text('\n'.join(CORE_PATHS)+'\n')
print(f'PASS: {len(CORE_PATHS)} frozen browser files byte-identical; 3 launch methods verbatim; core diff empty; 2 authorized scene-routing adapters excluded')
