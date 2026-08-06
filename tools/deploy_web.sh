#!/usr/bin/env bash
# Builds the Web export (via build_web.sh) and publishes it to the gh-pages
# branch (force-pushed as a single fresh commit each time, so the branch
# never accumulates build history).
#
# Usage:
#   ./tools/deploy_web.sh
#
# Requires:
#   - Everything tools/build_web.sh requires (see that script).
#   - git, with a remote (default: origin) you can push to -- e.g. via
#     `gh auth login && gh auth setup-git`, or an SSH key.
#
# After the first run, make sure GitHub Pages is set to serve from the
# gh-pages branch / root: repo Settings -> Pages -> Build and deployment.

set -euo pipefail

BRANCH="${DEPLOY_BRANCH:-gh-pages}"
REMOTE="${DEPLOY_REMOTE:-origin}"
BUILD_DIR="build/web"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
	echo "error: no git remote named '$REMOTE'. Run: git remote add $REMOTE <url>" >&2
	exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
	echo "warning: uncommitted changes present -- deploying the working tree as-is." >&2
fi

"$repo_root/tools/build_web.sh"

echo "==> Publishing to $REMOTE/$BRANCH..."
worktree_dir="$(mktemp -d)"
# Cleanup runs on any exit (success, error, or Ctrl-C): drop the scratch
# worktree, and the local branch ref it creates below -- otherwise the next
# run's `checkout --orphan` fails with "branch already exists" (it only
# needs to exist transiently, just to build the commit we push).
trap 'git worktree remove "$worktree_dir" --force >/dev/null 2>&1 || true; git branch -D "$BRANCH" >/dev/null 2>&1 || true' EXIT

# Belt-and-suspenders: also clear it up front, in case a previous run died
# before cleanup ran.
git branch -D "$BRANCH" >/dev/null 2>&1 || true

git worktree add --detach "$worktree_dir" >/dev/null
(
	cd "$worktree_dir"
	git checkout --orphan "$BRANCH" >/dev/null 2>&1
	git rm -rf . >/dev/null 2>&1 || true
	cp -r "$repo_root/$BUILD_DIR"/* .
	touch .nojekyll
	git add -A
	git commit -q -m "Deploy web build ($(date -u '+%Y-%m-%d %H:%M UTC'))"
	git push --force "$REMOTE" "HEAD:$BRANCH"
)

pages_url="$(git remote get-url "$REMOTE" | sed -E 's#.*[:/]([^/]+)/([^/.]+)(\.git)?$#https://\1.github.io/\2/#' | tr '[:upper:]' '[:lower:]')"
echo "==> Done: $pages_url"
echo "    (GitHub Pages may take a minute to pick up a fresh push.)"
