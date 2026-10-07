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

It also installs the third-party `cruise42.autostart-editor` plugin
(https://github.com/Cruise42/omarchy-autostart-editor) via Omarchy's own
`omarchy plugin add --enable` if it isn't already installed.

## What's NOT handled

Monitor layout (`~/.config/hypr/monitors.conf`) is specific to this
machine's ports and panels and is never auto-applied. See
`config/hypr/monitors.conf.example` for reference and set yours up manually
(or via `hyprmoncfg` / the autostart-editor panel).

The autostart-editor's login-app list (`config.json`) is linked into place,
but the plugin only writes real `~/.config/autostart/*.desktop` entries when
its "Apply" is triggered from the panel UI — a symlinked `config.json` alone
won't make apps autostart. **After running `install.sh`, open the Autostart
Editor panel once and click Apply** to actually activate the login-app list.