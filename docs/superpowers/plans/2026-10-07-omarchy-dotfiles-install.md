# Omarchy Dotfiles Install Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture this machine's Hyprland/Omarchy customizations into `soaparchy` and ship an idempotent `install.sh` that symlinks them into place on any Omarchy install, per `docs/superpowers/specs/2026-10-07-omarchy-dotfiles-design.md`.

**Architecture:** A `config/` tree in the repo mirrors the files under `~/.config` that we actually changed. `install.sh` is a single self-contained bash script: a `backup_and_link` function that backs up any pre-existing real file then symlinks the repo's copy into place (idempotent — skips if already correctly linked), a plugin-clone step for the third-party `cruise42.autostart-editor` plugin, and a `main` that wires both together over an explicit file-mapping list. Monitor layout is deliberately excluded from auto-deploy (machine-specific).

**Tech Stack:** Bash (no external dependencies beyond `git`, already required to clone this repo).

Per the spec's explicit "Out of scope" section, this script ships with **no automated test suite** (personal single-machine tooling, not a library). In place of unit tests, each implementation step below includes a manual verification command run against a throwaway sandbox directory (`/tmp/...`), so behavior is checked before anything touches the real `$HOME`. Nothing under `/tmp` is committed.

---

## File Structure

```
soaparchy/
  install.sh                                   # the whole script
  README.md                                    # usage
  config/
    hypr/
      bindings.lua
      input.lua
      autostart.lua
      hyprlock.conf
      monitors.conf.example                    # reference only, never auto-linked
    omarchy/
      shell.json
      bar/scripts/cpu-temp
      bar/scripts/cpu-usage
    autostart-editor/
      config.json                              # cruise42.autostart-editor state, Slack entry already fixed
```

One file (`install.sh`) is appropriate here — it's under ~120 lines total, all of it is one cohesive "lay down my dotfiles" responsibility, and splitting a script this small into a `lib/` would be pure ceremony (YAGNI).

---

### Task 1: Copy live config files into the repo

**Files:**
- Create: `config/hypr/bindings.lua`
- Create: `config/hypr/input.lua`
- Create: `config/hypr/autostart.lua`
- Create: `config/hypr/hyprlock.conf`
- Create: `config/hypr/monitors.conf.example`
- Create: `config/omarchy/shell.json`
- Create: `config/omarchy/bar/scripts/cpu-temp`
- Create: `config/omarchy/bar/scripts/cpu-usage`
- Create: `config/autostart-editor/config.json`

- [ ] **Step 1: Create the directory tree**

```bash
cd /home/farisabun/Documents/project/side/soaparchy
mkdir -p config/hypr config/omarchy/bar/scripts config/autostart-editor
```

- [ ] **Step 2: Copy each live file in**

```bash
cp ~/.config/hypr/bindings.lua          config/hypr/bindings.lua
cp ~/.config/hypr/input.lua             config/hypr/input.lua
cp ~/.config/hypr/autostart.lua         config/hypr/autostart.lua
cp ~/.config/hypr/hyprlock.conf         config/hypr/hyprlock.conf
cp ~/.config/hypr/monitors.conf         config/hypr/monitors.conf.example
cp ~/.config/omarchy/shell.json         config/omarchy/shell.json
cp ~/.config/omarchy/bar/scripts/cpu-temp  config/omarchy/bar/scripts/cpu-temp
cp ~/.config/omarchy/bar/scripts/cpu-usage config/omarchy/bar/scripts/cpu-usage
cp ~/.config/cruise42.autostart-editor/config.json config/autostart-editor/config.json
```

- [ ] **Step 3: Verify every copy is byte-identical to the live file**

Run:
```bash
diff ~/.config/hypr/bindings.lua          config/hypr/bindings.lua
diff ~/.config/hypr/input.lua             config/hypr/input.lua
diff ~/.config/hypr/autostart.lua         config/hypr/autostart.lua
diff ~/.config/hypr/hyprlock.conf         config/hypr/hyprlock.conf
diff ~/.config/hypr/monitors.conf         config/hypr/monitors.conf.example
diff ~/.config/omarchy/shell.json         config/omarchy/shell.json
diff ~/.config/omarchy/bar/scripts/cpu-temp  config/omarchy/bar/scripts/cpu-temp
diff ~/.config/omarchy/bar/scripts/cpu-usage config/omarchy/bar/scripts/cpu-usage
diff ~/.config/cruise42.autostart-editor/config.json config/autostart-editor/config.json
```
Expected: no output from any `diff` call (all identical).

- [ ] **Step 4: Preserve the bar scripts' executable bit**

```bash
chmod --reference=~/.config/omarchy/bar/scripts/cpu-temp  config/omarchy/bar/scripts/cpu-temp
chmod --reference=~/.config/omarchy/bar/scripts/cpu-usage config/omarchy/bar/scripts/cpu-usage
ls -l config/omarchy/bar/scripts/
```
Expected: both files show the executable bit (`-rwxr-xr-x` or similar, matching the live originals).

- [ ] **Step 5: Commit**

```bash
git add config/
git commit -m "Capture current Hyprland/Omarchy config files into repo"
```

---

### Task 2: `backup_and_link` function, verified in a sandbox

**Files:**
- Create: `install.sh`

- [ ] **Step 1: Write the script skeleton with the linking function**

```bash
cat > install.sh <<'SCRIPT'
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
SCRIPT
chmod +x install.sh
```

- [ ] **Step 2: Verify it fails loudly on bad input (sanity check `set -euo pipefail` is active)**

Run:
```bash
bash -c 'source install.sh; backup_and_link "/no/such/file" "/tmp/wherever"'
echo "exit code: $?"
```
Expected: non-zero exit code (the `mkdir -p "$(dirname "$dest")"` succeeds, but `ln -s` of a nonexistent source fails under `set -e`), confirming errors aren't silently swallowed.

- [ ] **Step 3: Verify first-time linking in a sandbox**

Run:
```bash
rm -rf /tmp/dotfiles-sandbox && mkdir -p /tmp/dotfiles-sandbox
DOTFILES_TARGET_HOME=/tmp/dotfiles-sandbox bash -c '
  source install.sh
  backup_and_link "$REPO_DIR/config/hypr/bindings.lua" "$TARGET_HOME/.config/hypr/bindings.lua"
'
ls -la /tmp/dotfiles-sandbox/.config/hypr/bindings.lua
```
Expected: last line shows a symlink (`lrwxrwxrwx ... bindings.lua -> /home/farisabun/.../config/hypr/bindings.lua`).

- [ ] **Step 4: Verify backup-then-link when a real file already exists at the target**

Run:
```bash
rm -rf /tmp/dotfiles-sandbox && mkdir -p /tmp/dotfiles-sandbox/.config/hypr
echo "pre-existing content" > /tmp/dotfiles-sandbox/.config/hypr/bindings.lua
DOTFILES_TARGET_HOME=/tmp/dotfiles-sandbox bash -c '
  source install.sh
  backup_and_link "$REPO_DIR/config/hypr/bindings.lua" "$TARGET_HOME/.config/hypr/bindings.lua"
'
readlink -f /tmp/dotfiles-sandbox/.config/hypr/bindings.lua
find /tmp/dotfiles-sandbox/.omarchy-dotfiles-backup -type f
```
Expected: `readlink -f` resolves to the repo's `config/hypr/bindings.lua`; the `find` shows exactly one backed-up file at `.../.omarchy-dotfiles-backup/<timestamp>/.config/hypr/bindings.lua` whose content is `pre-existing content`.

- [ ] **Step 5: Verify idempotency (running twice does nothing the second time)**

Run:
```bash
DOTFILES_TARGET_HOME=/tmp/dotfiles-sandbox bash -c '
  source install.sh
  backup_and_link "$REPO_DIR/config/hypr/bindings.lua" "$TARGET_HOME/.config/hypr/bindings.lua"
'
```
Expected: prints `  skip (already linked): /tmp/dotfiles-sandbox/.config/hypr/bindings.lua` and does not create a second backup directory.

```bash
rm -rf /tmp/dotfiles-sandbox
```

- [ ] **Step 6: Commit**

```bash
git add install.sh
git commit -m "Add backup_and_link core logic to install.sh"
```

---

### Task 3: Plugin clone step, file mapping, and `main`

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Add the plugin-clone function (append to `install.sh`, before any `main` logic)**

```bash
cat >> install.sh <<'SCRIPT'

PLUGIN_REPO="https://github.com/Cruise42/omarchy-autostart-editor.git"
PLUGIN_DIR="$TARGET_HOME/.config/omarchy/plugins/cruise42.autostart-editor"

ensure_plugin_cloned() {
  if [[ -d "$PLUGIN_DIR/.git" ]]; then
    echo "  already present, leaving as-is: $PLUGIN_DIR"
    return
  fi
  mkdir -p "$(dirname "$PLUGIN_DIR")"
  git clone "$PLUGIN_REPO" "$PLUGIN_DIR"
}
SCRIPT
```

- [ ] **Step 2: Verify the clone step against a local fake remote (no network dependency, no double-cloning the real plugin)**

Run:
```bash
rm -rf /tmp/fake-plugin-remote /tmp/dotfiles-sandbox
git init --bare /tmp/fake-plugin-remote -q
git clone -q /tmp/fake-plugin-remote /tmp/fake-plugin-seed
cd /tmp/fake-plugin-seed && touch README.md && git add . && git -c user.email=t@t -c user.name=t commit -qm seed && git push -q
cd /home/farisabun/Documents/project/side/soaparchy

mkdir -p /tmp/dotfiles-sandbox
DOTFILES_TARGET_HOME=/tmp/dotfiles-sandbox bash -c '
  source install.sh
  PLUGIN_REPO=/tmp/fake-plugin-remote
  PLUGIN_DIR="$TARGET_HOME/.config/omarchy/plugins/cruise42.autostart-editor"
  ensure_plugin_cloned
'
test -f /tmp/dotfiles-sandbox/.config/omarchy/plugins/cruise42.autostart-editor/README.md && echo "CLONE OK"
```
Expected: prints `CLONE OK`.

- [ ] **Step 3: Verify it leaves an existing clone alone**

Run:
```bash
DOTFILES_TARGET_HOME=/tmp/dotfiles-sandbox bash -c '
  source install.sh
  PLUGIN_REPO=/tmp/fake-plugin-remote
  PLUGIN_DIR="$TARGET_HOME/.config/omarchy/plugins/cruise42.autostart-editor"
  ensure_plugin_cloned
'
rm -rf /tmp/fake-plugin-remote /tmp/fake-plugin-seed /tmp/dotfiles-sandbox
```
Expected: prints `  already present, leaving as-is: /tmp/dotfiles-sandbox/.config/omarchy/plugins/cruise42.autostart-editor` (no second clone attempt, no error).

- [ ] **Step 4: Add the file mapping and `main` (append to `install.sh`)**

```bash
cat >> install.sh <<'SCRIPT'

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
  ensure_plugin_cloned
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
}

main "$@"
SCRIPT
```

- [ ] **Step 5: Verify a full end-to-end sandbox run**

Run:
```bash
rm -rf /tmp/dotfiles-sandbox && mkdir -p /tmp/dotfiles-sandbox
DOTFILES_TARGET_HOME=/tmp/dotfiles-sandbox bash install.sh
find /tmp/dotfiles-sandbox/.config -type l
```
Expected: the script prints the plugin clone (a real clone this time, from the real `PLUGIN_REPO`), then a `linked:` line for each of the 8 entries in `FILES`, then the backup/monitor note; the `find` lists all 8 symlinked paths under `/tmp/dotfiles-sandbox/.config`.

```bash
rm -rf /tmp/dotfiles-sandbox
```

- [ ] **Step 6: Commit**

```bash
git add install.sh
git commit -m "Wire install.sh main: plugin clone + file linking + summary"
```

---

### Task 4: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write it**

```bash
cat > README.md <<'EOF'
# soaparchy

Personal Hyprland/Omarchy customizations (keybindings, input, autostart,
bar scripts, the autostart-editor plugin's app list) and a script to
reproduce them on a fresh Omarchy install.

## Usage

```bash
git clone https://github.com/farisabundev/soaparchy.git
cd soaparchy
./install.sh
```

This symlinks the tracked config files from `config/` into `~/.config/...`,
backing up anything already there to `~/.omarchy-dotfiles-backup/<timestamp>/`.
Safe to re-run — already-linked files are skipped.

It also clones the third-party `cruise42.autostart-editor` plugin
(https://github.com/Cruise42/omarchy-autostart-editor) if it isn't already
installed.

## What's NOT handled

Monitor layout (`~/.config/hypr/monitors.conf`) is specific to this
machine's ports and panels and is never auto-applied. See
`config/hypr/monitors.conf.example` for reference and set yours up manually
(or via `hyprmoncfg` / the autostart-editor panel).

See `docs/superpowers/specs/2026-10-07-omarchy-dotfiles-design.md` for the
full design rationale.
EOF
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "Add README"
```

---

### Task 5: Run for real on this machine, then push

**Files:**
- None (verification + publish task)

- [ ] **Step 1: Run install.sh against the real `$HOME`**

```bash
cd /home/farisabun/Documents/project/side/soaparchy
./install.sh
```
Expected: plugin line prints `already present, leaving as-is: /home/farisabun/.config/omarchy/plugins/cruise42.autostart-editor` (it's already cloned); each of the 8 `FILES` entries prints a `backed up:` line followed by a `linked:` line, since right now they're still regular files (identical content to the repo copies from Task 1); ends with the backup-dir line and the monitors note.

- [ ] **Step 2: Verify the live files are now symlinks into the repo, and content is unchanged**

```bash
for f in ~/.config/hypr/bindings.lua ~/.config/hypr/input.lua ~/.config/hypr/autostart.lua \
         ~/.config/hypr/hyprlock.conf ~/.config/omarchy/shell.json \
         ~/.config/omarchy/bar/scripts/cpu-temp ~/.config/omarchy/bar/scripts/cpu-usage \
         ~/.config/cruise42.autostart-editor/config.json; do
  readlink -f "$f"
done
hyprctl reload
```
Expected: each `readlink -f` resolves into `/home/farisabun/Documents/project/side/soaparchy/config/...`; `hyprctl reload` exits cleanly (no parse errors from the now-symlinked Hyprland files).

- [ ] **Step 3: Confirm the backup directory holds the pre-install originals**

```bash
find ~/.omarchy-dotfiles-backup -type f | sort
```
Expected: 8 files, one per `FILES` entry, under a single timestamped subdirectory.

- [ ] **Step 4: Push to the existing GitHub remote**

```bash
cd /home/farisabun/Documents/project/side/soaparchy
git push -u origin master
```
Expected: succeeds (the `farisabundev/soaparchy` remote is empty, so this is a plain fast-forward push creating `master` on GitHub).

---

## Self-review notes

- **Spec coverage:** every row of the spec's file table is in `FILES` (Task 3) or created directly (Task 1); monitor exclusion is Task 3 Step 4 + README; symlink-not-copy and idempotency are Task 2; third-party plugin clone-if-missing is Task 3; backup-on-collision is Task 2 Step 4; the Slack fix is already baked into the `config.json` copied in Task 1 (fixed live earlier in this session).
- **No placeholders:** every step has runnable commands or complete script content, not descriptions.
- **No automated test suite shipped**, matching the spec's explicit out-of-scope call — verification happens via sandboxed manual runs during Tasks 2–3, not a committed `tests/` directory.
