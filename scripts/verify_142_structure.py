"""Source invariants complement (do not replace) the Xcode runtime tests."""
from pathlib import Path
import re
car=Path('WdCar/CarPlay/CarTemplateUI.swift').read_text()
phone=Path('WdCar/Phone/RootView.swift').read_text()
assert 'CPTabBarTemplate(templates: [home, library, television, entertainment])' in car
assert 'updateTemplates([self.home, self.library, self.television, self.entertainment])' in car
screens=['HomeView(selectTab:', 'SubscriptionGate { LibraryView() }', 'SubscriptionGate { XtreamHomeView() }', 'SettingsView(isSheet: false)']
positions=[phone.index(s) for s in screens]; assert positions==sorted(positions)
assert re.findall(r'\.tag\((\d)\)',phone)==['0','1','2','3']
assert 'SubscriptionGate { CarMousePadView() }' in Path('WdCar/Phone/SettingsView.swift').read_text()
for name in ['HomeView','CarScreenSheet']:
 source=Path('WdCar/Phone/'+name+'.swift').read_text()
 assert 'Color.green' in source and 'Color(.systemGray)' in source
 # Ignore comments; visible strings must use the new name.
 assert not any('المتصفح' in line for line in source.splitlines() if not line.lstrip().startswith('//'))
assert 'PHPickerViewController' in Path('WdCar/Media/MediaLibraryView.swift').read_text()
assert 'preferredForwardBufferDuration = PlayerPreferences.buffer' in Path('WdCar/Shared/PlaybackManager.swift').read_text()
print('PASS: tab order, subscription gate, compact status, picker and player preference wiring')

workflow = Path('codemagic.yaml').read_text().split('  wudcar-142-player:', 1)[1]
assert 'submit_to_testflight: false' in workflow and 'submit_to_app_store: false' in workflow
assert 'testFlightInternalTestingOnly' in workflow and 'skip-testing:' not in workflow
print('PASS: internal-only export/upload; no beta or App Store review and no skipped native test suites')
