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
config.status_update_interval = 500
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

wezterm.on("update-status", function(window, pane)
  local status_helper = wezterm.home_dir .. "/.local/bin/openclaw-tmux-status"
  local ok, stdout = wezterm.run_child_process({
    status_helper,
  })

  -- Keep a red session list available before Home Manager installs the helper.
  if not ok then
    local tmux = wezterm.home_dir .. "/.nix-profile/bin/tmux"
    ok, stdout = wezterm.run_child_process({
      tmux,
      "list-sessions",
      "-F",
      "#{session_name}",
    })
  end

  if not ok then
    window:set_right_status("")
    return
  end

  local colors = {
    finished = "#9ece6a",
    progressing = "#ff9e64",
    stopped = "#565f89",
  }
  local icons = {
    finished = "✓",
    progressing = "●",
    stopped = "○",
  }
  local sessions = {}
  for line in stdout:gmatch("[^\r\n]+") do
    local state, name = line:match("^(%S+)\t(.+)$")
    if not name then
      state, name = "stopped", line
    end
    table.insert(sessions, { state = state, name = name })
  end

  local elements = {}
  if #sessions > 0 then
    table.insert(elements, { Text = " tmux: " })
    for index, session in ipairs(sessions) do
      if index > 1 then
        table.insert(elements, { Foreground = { Color = "#7aa2f7" } })
        table.insert(elements, { Text = " • " })
      end
      table.insert(elements, {
        Foreground = { Color = colors[session.state] or colors.stopped },
      })
      table.insert(elements, { Attribute = { Intensity = "Bold" } })
      table.insert(elements, {
        Text = string.format("%s %s", icons[session.state] or icons.stopped, session.name),
      })
      table.insert(elements, { Attribute = { Intensity = "Normal" } })
    end
    table.insert(elements, { Text = " " })
  end
  window:set_right_status(wezterm.format(elements))
end)

return config
