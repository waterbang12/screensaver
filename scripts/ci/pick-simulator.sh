#!/usr/bin/env bash
# Picks an available iPhone simulator on the newest installed iOS runtime and
# prints KEY=VALUE lines (append them to $GITHUB_ENV). The choice is made from
# what the runner actually has, so it does not break when GitHub updates images.
set -euo pipefail

xcrun simctl list devices available --json | python3 -c '
import json, re, sys

data = json.load(sys.stdin)["devices"]
best = None
for runtime, devices in data.items():
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not m:
        continue
    version = (int(m.group(1)), int(m.group(2)))
    if version < (17, 0):
        continue  # deployment target is iOS 17
    for d in devices:
        name = d["name"]
        if not name.startswith("iPhone") or not d.get("isAvailable", True):
            continue
        # Prefer the newest runtime, then a 6.1" "Pro" model (393 pt wide, like the previews).
        score = (version, "Pro" in name and "Max" not in name, name)
        if best is None or score > best[0]:
            best = (score, d["udid"], name, "%d.%d" % version)

if best is None:
    sys.exit("No iPhone simulator with iOS 17+ is available on this runner.")
_, udid, name, version = best
print("SIM_UDID=" + udid)
print("SIM_NAME=" + name)
print("SIM_OS=" + version)
'
