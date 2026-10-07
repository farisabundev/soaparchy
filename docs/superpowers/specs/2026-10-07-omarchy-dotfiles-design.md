# Omarchy dotfiles repo (soaparchy) — design

## Purpose

Capture the Hyprland/Omarchy customizations made on this machine (keybindings,
input, autostart, bar scripts, plugin config) into this repo so a single
script can reproduce them on a fresh Omarchy install — this machine or
another.

## Scope

Only the files/settings that were actually changed from Omarchy defaults.
Not a full dotfiles repo (no shell config, git config, terminal emulator
config, etc. — can be added later as a separate scope if wanted).

Tracked files:

| Repo path | Deployed to | Notes |
|---|---|---|
| `config/hypr/bindings.lua` | `~/.config/hypr/bindings.lua` | Custom keybindings |
| `config/hypr/input.lua` | `~/.config/hypr/input.lua` | Caps Lock → Escape via `kb_options` |
| `config/hypr/autostart.lua` | `~/.config/hypr/autostart.lua` | Native boot layout (code/brave/terminals/etc.), `foot` terminal, `hyprlock` on boot |
| `config/hypr/hyprlock.conf` | `~/.config/hypr/hyprlock.conf` | Uses `~/.local/state/omarchy/current/...` paths |
| `config/hypr/monitors.conf.example` | *(not auto-deployed)* | Reference only — see Monitor handling below |
| `config/omarchy/shell.json` | `~/.config/omarchy/shell.json` | Bar module config incl. custom cpu-temp/cpu-usage |
| `config/omarchy/bar/scripts/cpu-temp` | `~/.config/omarchy/bar/scripts/cpu-temp` | Reads Tctl from hwmon |
| `config/omarchy/bar/scripts/cpu-usage` | `~/.config/omarchy/bar/scripts/cpu-usage` | Computed from `/proc/stat`, click opens btop |
| `config/autostart-editor/config.json` | `~/.config/cruise42.autostart-editor/config.json` | Login app list + workspace→monitor assignments, managed by the autostart-editor plugin. Includes the corrected Slack entry (native app, not the Brave web-app version). |

Not tracked (machine-specific, see below): `~/.config/hypr/monitors.conf` /
`monitors.lua` (actual, live version).

## Monitor handling

Monitor layout (`DP-3` left, `HDMI-A-1` right, specific panel models) is tied
to this PC's ports and panels and won't transfer to different hardware. The
repo ships `config/hypr/monitors.conf.example` as a reference (showing the
current layout) but `install.sh` does **not** symlink it over the live
`monitors.conf`. The script prints a reminder at the end of install to
reconfigure monitors manually (or via `hyprmoncfg` / the autostart-editor
panel) on any machine where the outputs differ.

## Third-party plugin

`cruise42.autostart-editor` is a third-party plugin (own git repo:
`https://github.com/Cruise42/omarchy-autostart-editor.git`), not something we
wrote. We only own and track its **config.json** (the login-app/workspace
state it manages), not its code.

Omarchy has its own plugin-management CLI (`omarchy plugin add/enable/list/
update`), separate from a plain `git clone`. `install.sh` installs the plugin
via `omarchy plugin add <repo> --enable --yes` when it isn't already present,
rather than cloning it directly — the official command manifest-validates
the plugin, registers it as enabled, and tells the running `omarchy-shell` to
rescan, none of which a bare clone does (it would sit on disk unrecognized
until a manual rescan/restart). If already present, install.sh leaves it
alone. This step always targets the real `$HOME` (Omarchy's CLI doesn't
support an alternate target directory) and requires a live Omarchy session —
acceptable since the whole script is Omarchy-specific anyway.

**Activation caveat:** the plugin's backend only writes real
`~/.config/autostart/*.desktop` entries when its `apply` action runs, and
`apply` is only ever invoked from the panel UI's own Apply/Save button
(confirmed in `AutostartEditor.qml` — no automatic apply-on-load). Symlinking
`config.json` into place updates the state the panel *would* show, but does
not by itself materialize the autostart entries. `install.sh` does not call
`apply` automatically — `apply`'s own validation hard-rejects the whole
payload if any workspace references a monitor name that isn't currently
connected (no fallback), which our baked-in `DP-3`/`HDMI-A-1` values would
trip on different hardware. Instead, `install.sh` prints a reminder: open the
Autostart Editor panel once after install and click Apply to activate the
login-app list. (If a command in that list isn't installed on the target
machine — e.g. Slack or Pear Desktop — the backend's `launch` action catches
the resulting `FileNotFoundError` as an `OSError` and exits with a JSON error;
that one app silently fails to open and nothing else is affected.)

## Deploy method

Symlinks, not copies. `install.sh`, for each tracked file:

1. If the target path is already a symlink pointing into this repo, skip (idempotent).
2. If the target path exists and is a real file/different symlink, back it up to `~/.omarchy-dotfiles-backup/<timestamp>/<relative-path>`.
3. Create parent directories as needed, then `ln -s` the repo file into place.

This keeps future edits to the live config automatically visible as repo
changes (`git status` in the repo shows what's dirty), at the cost of the
live file no longer being a plain file.

## install.sh behavior

- Bash script, safe to re-run (idempotent — re-running after no changes is a no-op).
- Checks prerequisites: `git`, running under Omarchy/Hyprland (soft check, warns but doesn't hard-fail if not detected, since you might pre-stage before first boot).
- Clones/updates the autostart-editor plugin.
- Symlinks all tracked files per the table above.
- Does **not** touch `monitors.conf`/`monitors.lua`.
- Ends with a short printed summary: what was linked, what was backed up (and where), and a reminder to reconfigure monitors.
- No uninstall/rollback command in this version — restoring from the timestamped backup directory is the rollback path if ever needed.

## Out of scope / explicitly deferred

- No CI, no tests (this is a shell script for personal machine setup).
- No support for multiple profiles/machines beyond the monitor carve-out above.
- No automated "sync back" — since files are symlinks, edits to the live
  config already land in the repo; you just `git add`/`commit` when you want
  to snapshot them.
