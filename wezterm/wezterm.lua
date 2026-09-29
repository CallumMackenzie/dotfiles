local wezterm = require("wezterm")

-- Start from WezTerm's defaults. The previous Ghostty config was empty, so
-- there are no terminal-specific overrides to translate.
local config = wezterm.config_builder()

-- Let tmux exclusively manage sessions, windows, and panes.
config.enable_tab_bar = false
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

return config
