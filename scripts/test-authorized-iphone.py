#!/usr/bin/env python3
"""Read-only Mac + authorized physical iPhone smoke. No IDs/names in output."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

def main():
    if sys.platform != "darwin":
        print("macOS / Xcode required", file=sys.stderr)
        return 2
    try:
        run = subprocess.run(
            ["/usr/bin/xcrun", "devicectl", "list", "devices", "--json-output", "-"],
            capture_output=True, text=True, check=True, timeout=30)
        raw = run.stdout
        devices = json.loads(raw[raw.index("{"):]).get("result", {}).get("devices", [])
    except (subprocess.SubprocessError, ValueError, KeyError):
        print("CoreDevice enumeration unavailable", file=sys.stderr)
        return 2
    physical = []
    for item in devices:
        hw = item.get("hardwareProperties") or {}
        conn = item.get("connectionProperties") or {}
        if (str(hw.get("productType", "")).startswith("iPhone")
                and hw.get("platform") == "iOS"
                and conn.get("transportType") == "wired"
                and conn.get("pairingState") == "paired"):
            physical.append(item)
    if len(physical) != 1:
        print("Requires exactly one paired authorized physical iPhone via USB", file=sys.stderr)
        return 2
    env = dict(os.environ)
    env["ME_AUTHORIZED_DEVICE_ID"] = physical[0]["identifier"]
    try:
        result = subprocess.run(
            ["swift", "test", "-j", "2", "--filter", "AuthorizedDeviceIntegrationTests"],
            cwd=Path(__file__).resolve().parents[1], env=env,
            capture_output=True, text=True, timeout=240)
    except (OSError, subprocess.TimeoutExpired):
        print("Swift integration did not complete", file=sys.stderr)
        return 1
    if result.returncode != 0:
        print("Swift device test failed; details withheld to protect private identifiers", file=sys.stderr)
        return 1
    match = re.search(r"AUTHORIZED_IPHONE_METADATA_COUNT=(\d+)", result.stdout + result.stderr)
    if not match:
        print("No confirmed nonempty Swift inventory; NOT validated", file=sys.stderr)
        return 1
    print("PASS: real Swift inventory parsed; %s entries, no IDs logged" % match.group(1))
    return 0

if __name__ == "__main__":
    sys.exit(main())
