#!/usr/bin/env bash
# Run ANY dev command in the background with its output piped to a log file,
# and record the process-group id so stop.sh can tear the whole tree down.
#
# This is framework-agnostic: it does not know about Flutter, React Native,
# Gradle, etc. You supply the run command after `--`; the per-framework
# reference (references/<framework>.md) tells you what that command is.
#
# Usage:
#   launch.sh [--log PATH] [--pidfile PATH] -- <command> [args...]
#
# Examples:
#   launch.sh -- flutter run -d emulator-5554 --target=lib/main.dart
#   launch.sh --log /tmp/rn.log -- npx react-native run-android
#   launch.sh -- ./gradlew :app:installDebug
#
# Defaults:
#   --log      ${TMPDIR:-/tmp}/visual-app-run.log
#   --pidfile  ${TMPDIR:-/tmp}/visual-app-run.pid
#
# `setsid` puts the command in its own process group so stop.sh can signal the
# whole tree with one `kill -- -<pgid>` — without it, child processes (a Metro
# bundler, a Dart daemon, a Gradle worker) outlive the wrapper and keep the
# device/port busy.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# shellcheck source=_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

LOG="${TMPDIR:-/tmp}/visual-app-run.log"
PIDFILE="${TMPDIR:-/tmp}/visual-app-run.pid"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log)     LOG="$2"; shift 2 ;;
    --pidfile) PIDFILE="$2"; shift 2 ;;
    --) shift; break ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown arg: $1 (did you forget '--' before the command?)"; exit 2 ;;
  esac
done

[[ $# -gt 0 ]] || { die "no command given after '--'"; exit 2; }
require_cmd setsid
require_cmd "$1"

: > "$LOG"
echo "launching: $*  →  $LOG" >&2
setsid nohup "$@" >"$LOG" 2>&1 < /dev/null &
echo $! > "$PIDFILE"
echo "pid=$(cat "$PIDFILE")  log=$LOG  pidfile=$PIDFILE"
