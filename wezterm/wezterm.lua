local wezterm = require("wezterm")

-- Start from WezTerm's defaults. The previous Ghostty config was empty, so
-- there are no terminal-specific overrides to translate.
local config = wezterm.config_builder()

-- Let tmux exclusively manage sessions, windows, and panes. Keep WezTerm's
-- tab bar as a minimal status strip, without exposing its own tabs or button.
config.enable_tab_bar = true
config.show_tabs_in_tab_bar = false
config.show_new_tab_button_in_tab_bar = false
config.use_fancy_tab_bar = false
config.status_update_interval = 3000
config.window_decorations = "RESIZE"
config.keys = {
  {
    key = "t",
    mods = "CMD",
    action = wezterm.action.DisableDefaultAssignment,
  },
}

-- Keep the desktop subtly visible while preserving text readability.
config.window_background_opacity = 0.88
config.macos_window_background_blur = 25
config.text_background_opacity = 0.92

-- Use the garden photo as a subdued terminal background.
config.window_background_image = wezterm.config_dir .. "/backgrounds/garden-koi.jpeg"
config.window_background_image_hsb = {
  brightness = 0.06,
  hue = 1.0,
  saturation = 0.85,
}

local function basename(path)
  return path and path:match("([^/\\]+)$") or ""
end

wezterm.on("update-status", function(window, pane)
  -- The foreground process seen by WezTerm is the tmux client for local
  -- sessions, so suppress the indicator while this pane is inside tmux.
  if basename(pane:get_foreground_process_name()) == "tmux" then
    window:set_right_status("")
    return
  end

  local tmux = wezterm.home_dir .. "/.nix-profile/bin/tmux"
  local ok, stdout = wezterm.run_child_process({
    tmux,
    "list-sessions",
    "-F",
    "#{session_name}",
  })

  -- Keep the pre-Nix bootstrap usable during migration.
  if not ok then
    ok, stdout = wezterm.run_child_process({
      "/opt/homebrew/bin/tmux",
      "list-sessions",
      "-F",
      "#{session_name}",
    })
  end

  if not ok then
    window:set_right_status("")
    return
  end

  local sessions = {}
  for name in stdout:gmatch("[^\r\n]+") do
    table.insert(sessions, name)
  end

  local status = ""
  if #sessions > 0 then
    status = " tmux: " .. table.concat(sessions, " • ") .. " "
  end
  window:set_right_status(status)
end)

return config
