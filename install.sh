#!/usr/bin/env bash
# Install skills into a Claude Code (or other agent) skills directory by
# DEREFERENCING symlinks, so each copied skill folder is fully self-contained.
#
# The skills in this repo share a common core (scripts/ + several references)
# via symlinks into ../../shared/. A plain `cp -r` of one skill folder would
# copy dangling symlinks; this script uses `cp -RL` to follow them and write
# real files — so the installed skill works standalone, on any OS, with no
# dependency on this repo. (The Claude Code plugin/marketplace install path
# does not need this — it clones the whole repo, so the symlinks resolve.)
#
# Usage:
#   ./install.sh                      # list available skills
#   ./install.sh <skill-name>         # install one skill to ~/.claude/skills/
#   ./install.sh all                  # install all skills
#   ./install.sh <skill-name> <dest>  # install to a custom skills dir,
#                                      #   e.g. .claude/skills (project scope)
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$REPO_DIR/skills"
DEST_DEFAULT="$HOME/.claude/skills"

list_skills() {
  find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
}

usage() {
  echo "Available skills:"
  list_skills | sed 's/^/  - /'
  echo
  echo "Usage:"
  echo "  ./install.sh <skill-name> [dest-dir]   # default dest: $DEST_DEFAULT"
  echo "  ./install.sh all [dest-dir]"
}

install_one() {
  local name="$1" dest="$2"
  local src="$SKILLS_DIR/$name"
  [[ -d "$src" ]] || { echo "error: no such skill '$name'" >&2; echo >&2; usage >&2; exit 1; }
  mkdir -p "$dest"
  rm -rf "${dest:?}/$name"
  # -R recursive, -L dereference symlinks → real, self-contained files.
  cp -RL "$src" "$dest/$name"
  echo "installed: $name → $dest/$name"
}

[[ $# -ge 1 ]] || { usage; exit 0; }

TARGET="$1"
DEST="${2:-$DEST_DEFAULT}"

if [[ "$TARGET" == "all" ]]; then
  while IFS= read -r s; do install_one "$s" "$DEST"; done < <(list_skills)
else
  install_one "$TARGET" "$DEST"
fi
