#!/usr/bin/env python3
"""Finish the existing upload only. Never archives, uploads, or submits review."""
import json
import subprocess
import time
from pathlib import Path

OUTPUT = Path("build/304-testflight-status")
OUTPUT.mkdir(parents=True, exist_ok=True)

def cli(*args):
    result = subprocess.run(["app-store-connect", "--no-color", "--json", *args],
                            check=True, capture_output=True, text=True, timeout=120)
    return json.loads(result.stdout)

deadline = time.monotonic() + 20 * 60
while True:
    builds = cli("builds", "list", "--app-id", "6823772404", "--pre-release-version", "3.0.1",
                 "--build-version-number", "4", "--platform", "IOS")
    assert isinstance(builds, list) and len(builds) <= 1, "Unexpected build selection"
    if builds:
        build = builds[0]
        assert build["attributes"]["version"] == "4", "Wrong build version"
        state = build["attributes"]["processingState"]
        print(json.dumps({"version": "3.0.1", "build": "4", "id": build["id"], "processingState": state}), flush=True)
        (OUTPUT / "build.json").write_text(json.dumps(build, indent=2))
        if state in ("FAILED", "INVALID"):
            raise RuntimeError("Apple processing failed; no new upload was attempted")
        if state == "VALID":
            build_id = build["id"]
            break
    else:
        print("Waiting for the existing 3.0.1 (4) upload to appear", flush=True)
    if time.monotonic() > deadline:
        raise TimeoutError("Existing upload still processing; no duplicate build or upload attempted")
    time.sleep(30)

# This command only adds an existing build to the named internal group. It does
# not submit a BetaAppReviewSubmission, set What to Test, or submit App Store review.
result = subprocess.run(["app-store-connect", "--no-color", "beta-groups", "add-build", build_id,
                         "--beta-group", "WudCar Internal"], check=True, capture_output=True, text=True, timeout=120)
print(result.stdout, flush=True)
print(result.stderr, flush=True)
details = cli("builds", "beta-details", build_id)
(OUTPUT / "beta-details.json").write_text(json.dumps(details, indent=2))
print(json.dumps({"buildID": build_id, "group": "WudCar Internal", "betaDetails": details}, indent=2), flush=True)
assert details["attributes"]["internalBuildState"] == "IN_BETA_TESTING", "Internal testing availability not confirmed"
print("CONFIRMED: WudCar 3.0.1 (4) is available for internal TestFlight testing", flush=True)
