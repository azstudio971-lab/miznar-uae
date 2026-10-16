#!/usr/bin/env python3
"""Check source configuration or the signed app; never print profile secrets."""
import argparse
import datetime as dt
import pathlib
import plistlib
import subprocess
import tempfile
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
VIDEO = 'com.apple.developer.carplay-video'
AUDIO = 'com.apple.developer.carplay-audio'
TEAM = 'QS29RVJPUT'
BUNDLE = 'com.azpixel.wudcar'

def require(value, message):
    if not value:
        raise SystemExit(message)

def check_entitlements(entitlements):
    require(entitlements.get(VIDEO) is True, 'Missing CarPlay Video entitlement')
    require(AUDIO not in entitlements, 'Audio and Video must not be combined')

def source():
    for name in ['CarPlay.entitlements', 'CarPlay.entitlements.example']:
        check_entitlements(plistlib.loads((ROOT / 'ios/WudCar' / name).read_bytes()))
    print('Video-only source configuration verified; portal/profile approval is a separate check.')

def signed_app(app):
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True, capture_output=True)
    signed = plistlib.loads(subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(app)], stderr=subprocess.DEVNULL))
    profile = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i', str(app / 'embedded.mobileprovision')]))
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    for entitlements in [signed, profile['Entitlements']]:
        check_entitlements(entitlements)
        require(entitlements.get('application-identifier') == TEAM + '.' + BUNDLE, 'Unexpected App ID')
        require(entitlements.get('com.apple.developer.team-identifier') == TEAM, 'Unexpected signing team')
        require(entitlements.get('get-task-allow') is False, 'Distribution profile required')
    require(info.get('CFBundleIdentifier') == BUNDLE, 'Unexpected bundle identifier')
    require(profile['ExpirationDate'].replace(tzinfo=dt.timezone.utc) > dt.datetime.now(dt.timezone.utc), 'Expired provisioning profile')
    require('ProvisionedDevices' not in profile and not profile.get('ProvisionsAllDevices'), 'App Store profile required')
    print('Signed app and embedded Video-only App Store profile verified.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--source', action='store_true')
    group.add_argument('--ipa', type=pathlib.Path)
    args = parser.parse_args()
    if args.source:
        source()
    else:
        with tempfile.TemporaryDirectory() as folder:
            with zipfile.ZipFile(args.ipa) as archive:
                for member in archive.namelist():
                    require(not pathlib.PurePosixPath(member).is_absolute() and '..' not in pathlib.PurePosixPath(member).parts, 'Unsafe archive member')
                archive.extractall(folder)
            apps = list(pathlib.Path(folder).glob('Payload/*.app'))
            require(len(apps) == 1, 'Expected exactly one app in IPA')
            signed_app(apps[0])
