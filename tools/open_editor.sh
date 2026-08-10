#!/usr/bin/env bash
# Launches the Godot editor with this project pre-selected -- skips the
# project manager list entirely.
#
# Usage:
#   ./tools/open_editor.sh
#
# Requires a Godot 4.7.x binary (GODOT_BIN env var to override the default
# path below).

set -euo pipefail

GODOT_BIN="${GODOT_BIN:-/home/user/Godot/Godot_v4.7.1-stable_linux.x86_64}"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [ ! -x "$GODOT_BIN" ]; then
	echo "error: Godot binary not found at '$GODOT_BIN'." >&2
	echo "       Set GODOT_BIN=/path/to/godot, or add godot to PATH." >&2
	exit 1
fi

echo "==> Opening the editor for $repo_root ..."
exec "$GODOT_BIN" --editor --path "$repo_root"
