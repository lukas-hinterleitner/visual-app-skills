#!/usr/bin/env bash
# Preflight: confirm an Android device/emulator is connected and pick one.
#
# Prints the chosen device serial on stdout (so callers can capture it), and a
# human-readable summary on stderr. Exits non-zero with a clear message when no
# device is ready, when a requested serial is absent, or when several are
# connected and none was pinned.
#
# Usage:
#   check-devices.sh            # require exactly one ready device, echo its serial
#   check-devices.sh -s <id>    # verify a specific serial is ready
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# shellcheck source=_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

SERIAL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--serial) SERIAL="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown arg: $1"; exit 2 ;;
  esac
done

require_cmd adb

serial="$(pick_device "$SERIAL")"
echo "ready: $serial" >&2
echo "$serial"
