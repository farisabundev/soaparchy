-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- Personal startup layout restored after the quattro migration.
--
-- Disabled 2026-09-23: handing autostart/workspace-placement over to the
-- cruise42.autostart-editor shell plugin, to avoid double-launching every
-- app (it manages its own delimited block in hyprland.lua). Re-enable this
-- block (and remove the plugin's block from hyprland.lua) if the plugin
-- doesn't work out.
--
-- hl.on("hyprland.start", function()
--   hl.exec_cmd(o.launch("code --restore-last-session"), { workspace = "1", silent = true })
--   hl.exec_cmd(o.launch("brave --restore-last-session"), { workspace = "2" })
--
--   -- Three terminals on workspace 5.
--   hl.exec_cmd(o.launch("foot"), { workspace = "5", silent = true })
--   hl.exec_cmd(o.launch("foot"), { workspace = "5", silent = true })
--   hl.exec_cmd(o.launch("foot"), { workspace = "5", silent = true })
--
--   hl.exec_cmd(o.launch("brave --new-window"), { workspace = "6", silent = true })
--   hl.exec_cmd(o.launch("slack"), { workspace = "7", silent = true })
--   hl.exec_cmd(o.launch("brave --app=https://web.whatsapp.com"), { workspace = "8", silent = true })
--   hl.exec_cmd(o.launch("pear-desktop"), { workspace = "9", silent = true })
-- end)

-- 2026-10-07: terminal (foot) autostart/placement moved back here from the
-- cruise42.autostart-editor plugin. The plugin's "placeInWorkspace" option
-- generates a persistent `o.window("foot", ...)` class rule, which pins
-- EVERY foot window to workspace 5 forever, not just the one launched at
-- login. exec_cmd's workspace arg only moves the window spawned by this one
-- call, so later terminals open wherever you actually are.
--
-- Kept active: the plugin doesn't manage lock-on-boot.
hl.on("hyprland.start", function()
  hl.exec_cmd(o.launch("foot"), { workspace = "5", silent = true })
  hl.exec_cmd("sh -c 'sleep 1 && hyprlock'")
end)
