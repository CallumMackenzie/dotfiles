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
config.status_update_interval = 350
config.window_decorations = "RESIZE"
config.colors = {
  tab_bar = {
    background = "rgba(17, 17, 27, 0.72)",
  },
}
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

local dashboard_colors = {
  text = "#cdd6f4",
  muted = "#7f849c",
  blue = "#89b4fa",
  green = "#a6e3a1",
  pink = "#f5c2e7",
  orange = "#fab387",
  stopped = "#585b70",
}

local username = wezterm.home_dir:match("([^/]+)$") or ""
local tmux_bin = "/etc/profiles/per-user/" .. username .. "/bin/tmux"

local function current_directory(pane, pane_tty)
  local path
  local tmux_ok, clients = wezterm.run_child_process({
    tmux_bin,
    "list-clients",
    "-F",
    "#{client_tty}\t#{pane_current_path}",
  })
  if tmux_ok then
    for line in clients:gmatch("[^\r\n]+") do
      local client_tty, client_path = line:match("^([^\t]+)\t(.+)$")
      if client_tty == pane_tty then
        path = client_path
        break
      end
    end
  end

  if not path then
    local cwd_uri = pane:get_current_working_dir()
    if type(cwd_uri) == "userdata" then
      path = cwd_uri.file_path
    elseif cwd_uri then
      path = tostring(cwd_uri):gsub("^file://[^/]*", "")
    end
  end
  if not path or path == "" then
    return "~", nil
  end

  local directory = path:match("([^/]+)/?$") or path
  local ok, branch = wezterm.run_child_process({
    "/usr/bin/git",
    "-C",
    path,
    "branch",
    "--show-current",
  })
  if ok then
    branch = branch:gsub("%s+$", "")
    if branch == "" then
      branch = nil
    end
  else
    branch = nil
  end

  return directory, branch
end

wezterm.on("update-status", function(window, pane)
  local status_helper = wezterm.home_dir .. "/.local/bin/openclaw-tmux-status"
  local pane_tty = pane:get_tty_name() or ""
  local ok, stdout = wezterm.run_child_process({
    status_helper,
    pane_tty,
  })

  -- Keep a red session list available before Home Manager installs the helper.
  if not ok then
    ok, stdout = wezterm.run_child_process({
      tmux_bin,
      "list-sessions",
      "-F",
      "#{session_name}",
    })
  end

  local colors = {
    finished = dashboard_colors.green,
    unread = dashboard_colors.pink,
    progressing = dashboard_colors.orange,
    stopped = dashboard_colors.stopped,
  }
  local icons = {
    finished = "✓",
    unread = "✓",
    progressing = "●",
    stopped = "○",
  }
  local sessions = {}
  if ok then
    for line in stdout:gmatch("[^\r\n]+") do
      local state, name, pane_states, active = line:match("^(%S+)\t([^\t]+)\t([^\t]+)\t(%S+)$")
      if not name then
        state, name, pane_states = line:match("^(%S+)\t([^\t]+)\t(.+)$")
        active = "inactive"
      end
      if not name then
        state, name, pane_states = "stopped", line, "stopped"
        active = "inactive"
      end
      local icons_for_session = {}
      for pane_state in pane_states:gmatch("[^,]+") do
        table.insert(icons_for_session, pane_state)
      end
      if #icons_for_session == 0 then
        table.insert(icons_for_session, "stopped")
      end
      table.insert(sessions, {
        state = state,
        name = name,
        pane_states = icons_for_session,
        active = active == "active",
      })
    end
  end

  local directory, branch = current_directory(pane, pane_tty)
  local left_elements = {
    { Foreground = { Color = dashboard_colors.blue } },
    { Attribute = { Intensity = "Bold" } },
    { Text = "    " .. directory },
  }
  if branch then
    table.insert(left_elements, { Foreground = { Color = dashboard_colors.muted } })
    table.insert(left_elements, { Text = "  •  " })
    table.insert(left_elements, { Foreground = { Color = dashboard_colors.green } })
    table.insert(left_elements, { Text = " " .. branch })
  end
  table.insert(left_elements, { Attribute = { Intensity = "Normal" } })
  window:set_left_status(wezterm.format(left_elements))

  local elements = {}
  if #sessions > 0 then
    table.insert(elements, { Foreground = { Color = dashboard_colors.muted } })
    table.insert(elements, { Text = "TMUX  " })
    for index, session in ipairs(sessions) do
      if index > 1 then
        table.insert(elements, { Foreground = { Color = dashboard_colors.muted } })
        table.insert(elements, { Text = "  •  " })
      end
      table.insert(elements, {
        Attribute = { Underline = session.active and "Single" or "None" },
      })
      table.insert(elements, { Attribute = { Intensity = "Bold" } })
      for icon_index, pane_state in ipairs(session.pane_states) do
        if icon_index > 1 then
          table.insert(elements, { Text = " " })
        end
        table.insert(elements, {
          Foreground = { Color = colors[pane_state] or colors.stopped },
        })
        table.insert(elements, { Text = icons[pane_state] or icons.stopped })
      end
      table.insert(elements, {
        Foreground = { Color = colors[session.state] or colors.stopped },
      })
      table.insert(elements, { Text = " " .. session.name })
      table.insert(elements, { Attribute = { Intensity = "Normal" } })
      table.insert(elements, { Attribute = { Underline = "None" } })
    end
    table.insert(elements, { Foreground = { Color = dashboard_colors.muted } })
    table.insert(elements, { Text = "  │  " })
  end
  table.insert(elements, { Foreground = { Color = dashboard_colors.text } })
  table.insert(elements, { Text = wezterm.strftime("%H:%M") .. "  " })
  window:set_right_status(wezterm.format(elements))
end)

return config
