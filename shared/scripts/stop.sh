#!/usr/bin/env bash
# Stop a background run started by launch.sh.
#
# launch.sh records the process-group leader's pid (it ran the command under
# `setsid`, so that pid is also the pgid). We signal the whole group with
# `kill -- -<pgid>` so children — a Metro bundler, a Dart `flutter_tools`
# daemon, a Gradle worker — die too, instead of being orphaned and holding the
# device/port.
#
# This does NOT force-stop the app on the device. To do that:
#   adb -s <id> shell am force-stop <applicationId>
#
# Usage:
#   stop.sh [--pidfile PATH]
#
# Default pidfile: ${TMPDIR:-/tmp}/visual-app-run.pid
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# shellcheck source=_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

PIDFILE="${TMPDIR:-/tmp}/visual-app-run.pid"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pidfile) PIDFILE="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown arg: $1"; exit 2 ;;
  esac
done

if [[ ! -f "$PIDFILE" ]]; then
  echo "no pidfile at $PIDFILE — nothing to stop" >&2
  exit 0
fi

pid="$(cat "$PIDFILE")"
if ! kill -0 "$pid" 2>/dev/null; then
  echo "pid $pid not running" >&2
  rm -f "$PIDFILE"
  exit 0
fi

# Try a graceful group TERM, then escalate to KILL.
kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
for _ in $(seq 1 10); do
  kill -0 "$pid" 2>/dev/null || break
  sleep 0.5
done
if kill -0 "$pid" 2>/dev/null; then
  kill -9 -- "-$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null || true
fi

rm -f "$PIDFILE"
echo "stopped pid=$pid (process group)"
