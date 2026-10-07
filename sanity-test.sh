#!/usr/bin/env bash
# Sandboxed sanity test for install.sh. Never touches the real ~/.config —
# everything runs against a throwaway dir under /tmp via DOTFILES_TARGET_HOME.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Sourcing install.sh (guarded against auto-running main) just to read its
# FILES array, so this test can't silently drift from what install.sh
# actually deploys.
source "$REPO_DIR/install.sh"

PASS=0
FAIL=0

check() {
  local desc="$1"
  shift
  if "$@"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

SANDBOX="$(mktemp -d /tmp/soaparchy-sanity-test.XXXXXX)"
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

echo "=== 1. Syntax check ==="
check "install.sh has valid bash syntax" bash -n "$REPO_DIR/install.sh"
echo

echo "=== 2. Fresh install ==="
DOTFILES_TARGET_HOME="$SANDBOX" bash "$REPO_DIR/install.sh" >/dev/null
for entry in "${FILES[@]}"; do
  target_rel="${entry##*:}"
  check "linked: $target_rel" test -L "$SANDBOX/$target_rel"
done
echo

echo "=== 3. Idempotent re-run ==="
output="$(DOTFILES_TARGET_HOME="$SANDBOX" bash "$REPO_DIR/install.sh" 2>&1)"
skip_count="$(grep -c '^  skip (already linked):' <<<"$output" || true)"
check "all ${#FILES[@]} entries skipped on re-run" [ "$skip_count" -eq "${#FILES[@]}" ]
check "no backup directory created on a no-op run" [ ! -d "$SANDBOX/.omarchy-dotfiles-backup" ]
echo

echo "=== 4. Collision handling ==="
rm -rf "$SANDBOX" && mkdir -p "$SANDBOX/.config/hypr"
echo "sanity-test sentinel content" >"$SANDBOX/.config/hypr/bindings.lua"
DOTFILES_TARGET_HOME="$SANDBOX" bash "$REPO_DIR/install.sh" >/dev/null
backup_file="$(find "$SANDBOX/.omarchy-dotfiles-backup" -type f -name bindings.lua 2>/dev/null | head -1)"
check "pre-existing file was backed up" [ -n "$backup_file" ]
check "backup preserved the original content" grep -q "sanity-test sentinel content" "$backup_file"
check "target is now a symlink into the repo" [ "$(readlink -f "$SANDBOX/.config/hypr/bindings.lua")" = "$REPO_DIR/config/hypr/bindings.lua" ]
echo

echo "=== 5. Content integrity ==="
for entry in "${FILES[@]}"; do
  repo_rel="${entry%%:*}"
  target_rel="${entry##*:}"
  check "content matches: $repo_rel" diff -q "$SANDBOX/$target_rel" "$REPO_DIR/$repo_rel"
done
echo

echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
