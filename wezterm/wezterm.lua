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

return config
