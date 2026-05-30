#!/usr/bin/env bash
# Dump recent Android logs to stdout (or a file). Wraps `adb logcat -d`.
#
# `-d` dumps the current buffer and exits (no follow), so this is safe to call
# from an agent loop without leaving a process running. Pick how to scope it:
#
#   --app <applicationId>   only this app's process (resolves its pid)
#   --filter "<spec>"       a raw logcat filterspec, e.g. "*:E ReactNative:V"
#   (neither)               defaults to "*:E" — errors from every tag
#
# Avoid an unfiltered dump: the full buffer is huge and drowns the signal.
#
# Usage:
#   capture-logs.sh [-s <id>] [-n <lines>] [--app <id> | --filter "<spec>"] [output.txt]
#
# Examples:
#   capture-logs.sh                                   # last 300 error lines, stdout
#   capture-logs.sh --app com.example.app /tmp/log.txt
#   capture-logs.sh --filter "*:S flutter:V" -n 500
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# shellcheck source=_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

SERIAL=""
LINES=300
APP=""
FILTER=""
OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--serial) SERIAL="$2"; shift 2 ;;
    -n|--lines)  LINES="$2"; shift 2 ;;
    --app)       APP="$2"; shift 2 ;;
    --filter)    FILTER="$2"; shift 2 ;;
    -h|--help)   grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) OUT="$1"; shift ;;
  esac
done

require_cmd adb
serial="$(pick_device "$SERIAL")"

cmd=(adb -s "$serial" logcat -d -t "$LINES")

if [[ -n "$APP" ]]; then
  pid="$(adb -s "$serial" shell pidof -s "$APP" 2>/dev/null | tr -d '\r' || true)"
  [[ -n "$pid" ]] || { die "app '$APP' is not running on $serial (no pid) — launch it first"; exit 1; }
  cmd+=(--pid="$pid")
elif [[ -n "$FILTER" ]]; then
  # shellcheck disable=SC2206  # intentional word-split of the filterspec
  cmd+=($FILTER)
else
  cmd+=("*:E")
fi

if [[ -n "$OUT" ]]; then
  "${cmd[@]}" > "$OUT"
  echo "$OUT  (device=$serial, last $LINES)" >&2
else
  "${cmd[@]}"
fi
