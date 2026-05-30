#!/usr/bin/env bash
# Capture an Android screenshot straight to a host PNG.
#
# Uses `adb exec-out screencap -p` — this streams the raw PNG over the adb
# protocol with no temp file on the device and no `adb pull`. Do NOT use
# `adb shell screencap -p > file.png`: on some setups the shell layer
# CR-LF-translates the binary stream and produces a corrupt PNG. `exec-out`
# bypasses that.
#
# Usage:
#   snap.sh [-s|--serial <id>] <output.png>
#
# Picks the single connected device by default; requires --serial when more
# than one is attached.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# shellcheck source=_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

SERIAL=""
OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--serial) SERIAL="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) OUT="$1"; shift ;;
  esac
done

[[ -n "$OUT" ]] || { die "missing output path (e.g. /tmp/screen.png)"; exit 2; }
require_cmd adb

serial="$(pick_device "$SERIAL")"
adb -s "$serial" exec-out screencap -p > "$OUT"

[[ -s "$OUT" ]] || { die "screencap returned no bytes (device asleep? GPU stuck?)"; exit 1; }

size=$(stat -c%s "$OUT" 2>/dev/null || stat -f%z "$OUT")
echo "$OUT  ($size bytes, device=$serial)"
