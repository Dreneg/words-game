#!/usr/bin/env bash
# Builds the Godot Web export into build/web/ -- nothing is published
# anywhere. Use this to preview a build locally before running
# tools/deploy_web.sh (which calls this script, then publishes the result).
#
# Usage:
#   ./tools/build_web.sh            # just build
#   ./tools/build_web.sh --serve    # build, then serve locally and print the URL
#
# Requires a Godot 4.7.x binary with the Web export templates installed
# (GODOT_BIN env var to override the default path below).

set -euo pipefail

GODOT_BIN="${GODOT_BIN:-/home/user/Godot/Godot_v4.7.1-stable_linux.x86_64}"
BUILD_DIR="build/web"
SERVE_PORT="${SERVE_PORT:-8060}"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [ ! -x "$GODOT_BIN" ]; then
	echo "error: Godot binary not found at '$GODOT_BIN'." >&2
	echo "       Set GODOT_BIN=/path/to/godot, or add godot to PATH." >&2
	exit 1
fi

echo "==> Building Web export..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
"$GODOT_BIN" --headless --path . --export-release "Web" "$BUILD_DIR/index.html"

if [ ! -f "$BUILD_DIR/index.html" ]; then
	echo "error: export did not produce $BUILD_DIR/index.html -- check the log above." >&2
	exit 1
fi

echo "==> Built: $BUILD_DIR/"

if [ "${1:-}" = "--serve" ]; then
	echo "==> Serving at http://localhost:$SERVE_PORT/ (Ctrl-C to stop)"
	cd "$BUILD_DIR"
	exec python3 -m http.server "$SERVE_PORT"
fi
