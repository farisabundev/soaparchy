#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HOME="${DOTFILES_TARGET_HOME:-$HOME}"
BACKUP_DIR="$TARGET_HOME/.omarchy-dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

backup_and_link() {
  local src="$1" dest="$2"
  if [[ -L "$dest" ]] && [[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
    echo "  skip (already linked): $dest"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" || -L "$dest" ]]; then
    local rel="${dest#"$TARGET_HOME"/}"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    mv "$dest" "$BACKUP_DIR/$rel"
    echo "  backed up: $dest -> $BACKUP_DIR/$rel"
  fi
  ln -s "$src" "$dest"
  echo "  linked: $dest -> $src"
}

PLUGIN_ID="cruise42.autostart-editor"
PLUGIN_REPO="https://github.com/Cruise42/omarchy-autostart-editor.git"
# Omarchy's own plugin CLI always operates on the real $HOME regardless of
# any TARGET_HOME override, so this check must too — otherwise a sandboxed
# test run would wrongly conclude "not installed" and try to really install it.
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

# Goes through Omarchy's own plugin CLI (not a plain git clone) so the
# plugin is manifest-validated, registered as enabled, and the running
# omarchy-shell is told to rescan — a raw clone would leave it on disk
# but invisible until a manual rescan/restart.
ensure_plugin_cloned() {
  if [[ -d "$PLUGIN_DIR" ]]; then
    echo "  already present, leaving as-is: $PLUGIN_DIR"
    return
  fi
  command -v omarchy >/dev/null || {
    echo "  'omarchy' CLI not found — can't install $PLUGIN_ID this way." >&2
    echo "  Run manually: omarchy plugin add $PLUGIN_REPO --enable" >&2
    return 1
  }
  omarchy plugin add "$PLUGIN_REPO" --enable --yes
}

FILES=(
  "config/hypr/bindings.lua:.config/hypr/bindings.lua"
  "config/hypr/input.lua:.config/hypr/input.lua"
  "config/hypr/autostart.lua:.config/hypr/autostart.lua"
  "config/hypr/hyprlock.conf:.config/hypr/hyprlock.conf"
  "config/omarchy/shell.json:.config/omarchy/shell.json"
  "config/omarchy/bar/scripts/cpu-temp:.config/omarchy/bar/scripts/cpu-temp"
  "config/omarchy/bar/scripts/cpu-usage:.config/omarchy/bar/scripts/cpu-usage"
  "config/autostart-editor/config.json:.config/cruise42.autostart-editor/config.json"
)

main() {
  echo "Omarchy dotfiles install -> $TARGET_HOME"
  echo

  echo "Autostart-editor plugin:"
  ensure_plugin_cloned || echo "  WARNING: plugin install step failed; continuing with the rest of the install"
  echo

  echo "Linking config files:"
  for entry in "${FILES[@]}"; do
    local repo_rel="${entry%%:*}"
    local target_rel="${entry##*:}"
    backup_and_link "$REPO_DIR/$repo_rel" "$TARGET_HOME/$target_rel"
  done
  echo

  if [[ -d "$BACKUP_DIR" ]]; then
    echo "Pre-existing files were backed up to: $BACKUP_DIR"
  fi
  echo
  echo "NOTE: monitors.conf was NOT touched (machine-specific)."
  echo "      Reconfigure your monitor layout manually, or compare against"
  echo "      config/hypr/monitors.conf.example for reference."
  echo
  echo "NOTE: the Autostart Editor's login-app list (config.json) is now"
  echo "      linked, but the plugin only writes real autostart entries when"
  echo "      its 'Apply' is triggered from the panel UI. Open the Autostart"
  echo "      Editor panel once and click Apply to activate it."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
