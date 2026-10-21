#!/usr/bin/env python3
"""Fail release preparation unless the real-app YouTube probe passed (skips are insufficient)."""
import pathlib
import json
import re
import sys

log = pathlib.Path(sys.argv[1]).read_text(errors="replace")
pattern = r"Test Case '[^\n]*testLiveYouTubePhoneBeforeCarProbe[^\n]*' passed"
if not re.search(pattern, log):
    sys.exit("BLOCKED: live YouTube desktop verification did not pass. Do not upload this build.")
acceptance = json.loads(pathlib.Path("Config/BrowserAcceptance160.json").read_text())
for target in ("iphoneYouTubeDesktop", "carPlayYouTubeDesktop"):
    evidence = acceptance.get(target, {})
    if evidence.get("verified") is not True or not evidence.get("evidence", "").strip():
        sys.exit(f"BLOCKED: {target} has no verified acceptance evidence. Do not upload this build.")
print("YouTube desktop probe passed and both device acceptance records contain verified evidence.")
