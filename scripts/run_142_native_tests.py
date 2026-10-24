"""Run native tests with bounded cleanup and file-backed logs (no inherited tee pipe)."""
import argparse
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

parser = argparse.ArgumentParser()
parser.add_argument('--device', required=True)
args = parser.parse_args()
log = Path('/tmp/wudcar-160-release-gate.log')
command = [
    '/usr/bin/xcodebuild', '-project', 'WdCar.xcodeproj', '-scheme', 'WdCarTests',
    '-destination', f'platform=iOS Simulator,id={args.device}',
    '-only-testing:WdCarTests/Release160Tests',
    '-only-testing:WdCarTests/Release17Tests',
    '-only-testing:WdCarTests/Release142PlayerTests',
    '-parallel-testing-enabled', 'NO', '-collect-test-diagnostics', 'never', '-test-timeouts-enabled', 'YES',
    '-default-test-execution-time-allowance', '180', '-maximum-test-execution-time-allowance', '240',
    '-resultBundlePath', '/tmp/WudCar160ReleaseGate.xcresult',
    'CODE_SIGNING_ALLOWED=YES', 'CODE_SIGNING_REQUIRED=YES', 'CODE_SIGN_IDENTITY=-', 'test'
]
# Descendants write to a regular file, so a retained descriptor cannot keep a tee
# pipeline alive after xcodebuild exits. Preserve its real exit status; never infer
# success solely from an "All tests passed" console line.
with log.open('wb') as output, log.open('r', errors='replace') as reader:
    process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=output,
                               stderr=subprocess.STDOUT, start_new_session=True)
    deadline = time.monotonic() + 12 * 60
    while process.poll() is None:
        chunk = reader.read()
        if chunk:
            print(chunk, end='', flush=True)
        if time.monotonic() > deadline:
            print('\nERROR: XCTest process did not finish within 12 minutes. No release approval.', flush=True)
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            sys.exit(124)
        time.sleep(0.2)
    print(reader.read(), end='', flush=True)
    sys.exit(process.returncode)
