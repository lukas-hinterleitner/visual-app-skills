# Shared helpers sourced by the other scripts in this directory.
# Not meant to be run directly.
#
# SPDX-License-Identifier: Apache-2.0

# Fail with a message on stderr and return non-zero.
die() { echo "error: $*" >&2; return 1; }

# Verify a command is on PATH.
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' not on PATH"
}

# Echo every device serial currently in the 'device' state, one per line.
# Skips offline/unauthorized entries and the "List of devices" header.
adb_devices_ready() {
  adb devices | awk 'NR>1 && $2=="device" {print $1}'
}

# pick_device [serial]
# Echoes the device serial to target on stdout, or fails with a clear message.
#   - with a serial argument: verify it is connected and ready.
#   - without: require exactly one ready device (refuse to guess when many).
pick_device() {
  local want="${1:-}"
  local devices
  devices="$(adb_devices_ready)"

  if [[ -z "$devices" ]]; then
    die "no Android device or emulator connected (\`adb devices\` lists none ready)"
    return 1
  fi

  if [[ -n "$want" ]]; then
    if grep -qxF -- "$want" <<<"$devices"; then
      echo "$want"
      return 0
    fi
    {
      echo "error: device '$want' is not connected/ready. Ready devices:"
      echo "$devices"
    } >&2
    return 1
  fi

  if [[ "$(wc -l <<<"$devices")" -gt 1 ]]; then
    {
      echo "error: multiple devices connected — pin one with -s/--serial:"
      echo "$devices"
    } >&2
    return 1
  fi

  echo "$devices"
}
