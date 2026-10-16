#!/usr/bin/env python3
"""Generate a deterministic, dependency-free Xcode project. Run from any directory."""
from pathlib import Path
import hashlib, json, plistlib, shutil, subprocess, sys
root = Path(__file__).resolve().parents[1]
ios = root / 'ios'
app = ios / 'WudCar'
assets = app / 'Resources/Assets.xcassets'
assets.mkdir(parents=True, exist_ok=True)
def catalog(name, source, icon=False):
    target = assets / (name + ('.appiconset' if icon else '.imageset'))
    target.mkdir(exist_ok=True)
    shutil.copyfile(source, target / 'image.png')
    if icon:
        if sys.platform == 'darwin': subprocess.run(['sips','-z','1024','1024',str(target/'image.png')],check=True,capture_output=True)
        else:
            from PIL import Image
            Image.open(source).convert('RGB').resize((1024,1024), Image.Resampling.LANCZOS).save(target/'image.png')
    image = {'filename':'image.png','idiom':'universal'}
    if icon: image.update({'platform':'ios','size':'1024x1024'})
    (target/'Contents.json').write_text(json.dumps({'images':[image],'info':{'author':'xcode','version':1}},indent=2))
(assets/'Contents.json').write_text('{"info":{"author":"xcode","version":1}}')
# Original approved artwork is kept in assets/. Resource copies use identical Git blobs.
catalog('AppIcon',root/'assets/wudcar/WudCar-App-Icon.png',True)
catalog('BrandIcon',root/'assets/wudcar/WudCar-App-Icon.png')
for shape in ['compact','ultrawide']:
    for period in ['dawn','morning','sunset','night']:
        catalog(f'{shape}-{period}',root/f'assets/themes/spirit-of-the-uae/{shape}/{period}.png')
info = {'CFBundleDevelopmentRegion':'en','CFBundleDisplayName':'WudCar','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)','CFBundlePackageType':'APPL','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)','LSRequiresIPhoneOS':True,'UILaunchScreen':{},'UIBackgroundModes':['audio','remote-notification'],'NSLocationWhenInUseUsageDescription':'يستخدم موقعك لعرض الطقس والتوقيت ومواقيت الصلاة واستهداف إشعارات منطقتك. Your location sets weather, time, prayer times and regional notifications.','WUD_APNS_ENVIRONMENT':'$(WUD_APNS_ENVIRONMENT)','UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],'UISupportedInterfaceOrientations~ipad':['UIInterfaceOrientationPortrait','UIInterfaceOrientationPortraitUpsideDown','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],'CFBundleLocalizations':['ar','en'],'WUD_SUPABASE_URL':'$(WUD_SUPABASE_URL)','WUD_SUPABASE_KEY':'$(WUD_SUPABASE_KEY)'}
# CarPlay Audio was assigned to this team and enabled for this App ID on 2026-10-10.
info['UIApplicationSceneManifest']={'UIApplicationSupportsMultipleScenes':True,'UISceneConfigurations':{'CPTemplateApplicationSceneSessionRoleApplication':[{'UISceneConfigurationName':'CarPlay','UISceneClassName':'CPTemplateApplicationScene','UISceneDelegateClassName':'$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate'}]}}
(app/'Info.plist').write_bytes(plistlib.dumps(info))
# Keep the alternate plist and example for existing recovery documentation.
car = dict(info)
car['UIApplicationSceneManifest']={'UIApplicationSupportsMultipleScenes':True,'UISceneConfigurations':{'CPTemplateApplicationSceneSessionRoleApplication':[{'UISceneConfigurationName':'CarPlay','UISceneClassName':'CPTemplateApplicationScene','UISceneDelegateClassName':'$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate'}]}}
(app/'Info-CarPlay.plist').write_bytes(plistlib.dumps(car))
(app/'CarPlay.entitlements.example').write_bytes(plistlib.dumps({'com.apple.developer.carplay-audio':True}))

def uid(s): return hashlib.sha256(s.encode()).hexdigest()[:24].upper()
def q(s): return json.dumps(str(s))
objects=[]
def obj(key,body): objects.append(f'{uid(key)} = {{ {body} }};'); return uid(key)
sources = sorted(p.relative_to(ios).as_posix() for p in app.rglob('*.swift'))
resources = ['WudCar/Resources/Assets.xcassets','WudCar/Resources/policies.json','WudCar/Resources/PrivacyInfo.xcprivacy']
file_ids=[]; source_build=[]; resource_build=[]
for path in sources+resources:
    typ='sourcecode.swift' if path.endswith('.swift') else 'folder.assetcatalog' if path.endswith('.xcassets') else 'text.plist.xml' if path.endswith('.xcprivacy') else 'text.json'
    f=obj('file:'+path,f'isa = PBXFileReference; lastKnownFileType = {typ}; path = {q(path)}; sourceTree = SOURCE_ROOT;')
    file_ids.append(f)
    b=obj('build:'+path,f'isa = PBXBuildFile; fileRef = {f};')
    (source_build if path in sources else resource_build).append(b)
product=obj('product','isa = PBXFileReference; explicitFileType = wrapper.application; path = WudCar.app; sourceTree = BUILT_PRODUCTS_DIR;')
products=obj('products',f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
main=obj('main',f'isa = PBXGroup; children = ({",".join(file_ids+[products])},); sourceTree = "<group>";')
sp=obj('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(source_build)},); runOnlyForDeploymentPostprocessing = 0;')
rp=obj('resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(resource_build)},); runOnlyForDeploymentPostprocessing = 0;')
fp=obj('frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
configref=obj('configref','isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Config.xcconfig; sourceTree = SOURCE_ROOT;')
for level in ['project','target']:
    configs=[]
    for mode in ['Debug','Release']:
        settings={'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O'}
        if level=='target': settings.update({'PRODUCT_NAME':'WudCar','PRODUCT_BUNDLE_IDENTIFIER':'com.azpixel.wudcar','DEVELOPMENT_TEAM':'QS29RVJPUT','CODE_SIGN_STYLE':'Automatic','INFOPLIST_FILE':'WudCar/Info.plist','CODE_SIGN_ENTITLEMENTS':'WudCar/CarPlay.entitlements','TARGETED_DEVICE_FAMILY':'1,2','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','MARKETING_VERSION':'1.1.1','CURRENT_PROJECT_VERSION':'112','GENERATE_INFOPLIST_FILE':'NO','SWIFT_EMIT_LOC_STRINGS':'YES','ENABLE_USER_SCRIPT_SANDBOXING':'YES'})
        body=' '.join(f'{k} = {q(v)};' for k,v in settings.items())
        configs.append(obj(level+mode,f'isa = XCBuildConfiguration; baseConfigurationReference = {configref}; buildSettings = {{ {body} }}; name = {mode};'))
    obj(level+'configs',f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target=obj('target',f'isa = PBXNativeTarget; buildConfigurationList = {uid("targetconfigs")}; buildPhases = ({sp},{fp},{rp},); buildRules = (); dependencies = (); name = WudCar; productName = WudCar; productReference = {product}; productType = "com.apple.product-type.application";')
project=obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {uid("projectconfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,ar,Base); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
folder=ios/'WudCar.xcodeproj';folder.mkdir(exist_ok=True)
(folder/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {project}; }}\n')
scheme=folder/'xcshareddata/xcschemes';scheme.mkdir(parents=True,exist_ok=True)
ref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="WudCar.app" BlueprintName="WudCar" ReferencedContainer="container:WudCar.xcodeproj"/>'
(scheme/'WudCar.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?><Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print('Generated ios/WudCar.xcodeproj')
