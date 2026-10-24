"""Attach the unchanged local StoreKit fixture to XCTest's Test action, not only Run."""
from pathlib import Path
import json, xml.etree.ElementTree as ET
scheme = Path('WdCar.xcodeproj/xcshareddata/xcschemes/WdCarTests.xcscheme')
tree = ET.parse(scheme); root = tree.getroot()
action = root.find('TestAction'); assert action is not None
refs = root.findall('.//BuildableReference')
test_ref = next(r for r in refs if r.get('BlueprintName') == 'WdCarTests')
app_ref = next(r for r in refs if r.get('BlueprintName') == 'WdCar')
def target(r):
    return {'containerPath': 'container:WdCar.xcodeproj', 'identifier': r.get('BlueprintIdentifier'), 'name': r.get('BlueprintName')}
plan = {
    'configurations': [{'id': '14200000-0000-0000-0000-000000000001', 'name': 'Local StoreKit', 'options': {}}],
    'defaultOptions': {
        'targetForVariableExpansion': target(app_ref),
        'storeKitConfiguration': {'relativePath': 'WdCarTests/WudCar.storekit'},
        'testTimeoutsEnabled': True,
        'defaultTestExecutionTimeAllowance': 120,
        'maximumTestExecutionTimeAllowance': 180
    },
    'testTargets': [{'target': target(test_ref), 'parallelizable': False}], 'version': 1
}
Path('Release142.xctestplan').write_text(json.dumps(plan, indent=2)+'\n')
for name in ['Testables', 'TestPlans']:
    child = action.find(name)
    if child is not None: action.remove(child)
plans = ET.SubElement(action, 'TestPlans')
ET.SubElement(plans, 'TestPlanReference', {'reference': 'container:Release142.xctestplan', 'default': 'YES'})
tree.write(scheme, encoding='UTF-8', xml_declaration=True)
assert Path(plan['defaultOptions']['storeKitConfiguration']['relativePath']).exists()
print('Configured XCTest plan with unchanged WudCar.storekit and all native tests; no app/product changes.')
