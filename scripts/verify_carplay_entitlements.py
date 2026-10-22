#!/usr/bin/env python3
"""Check the signed app, not just project settings, before TestFlight upload."""
import plistlib
import sys

AUDIO = "com.apple.developer.carplay-audio"
VIDEO = "com.apple.developer.carplay-video"


def verify(app, profile):
    if app.get(VIDEO) is not True:
        raise ValueError("Signed app must include CarPlay Video = true")
    if AUDIO in app:
        raise ValueError("Signed app must not include CarPlay Audio")
    if profile.get("Entitlements", {}).get(VIDEO) is not True:
        raise ValueError("Provisioning profile must authorize CarPlay Video")


if __name__ == "__main__":
    try:
        with open(sys.argv[1], "rb") as source:
            app = plistlib.load(source)
        with open(sys.argv[2], "rb") as source:
            profile = plistlib.load(source)
        verify(app, profile)
    except (ValueError, OSError, IndexError, plistlib.InvalidFileException) as error:
        sys.exit(f"CarPlay entitlement verification FAILED: {error}")
    print("PASS: signed app has CarPlay Video only; Audio absent; profile authorizes Video")
