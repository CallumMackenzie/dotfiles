hs.hotkey.bind({ "cmd", "alt" }, "0", function()
  hs.application.launchOrFocus("Ghostty")
end)

hs.hotkey.bind({ "cmd", "alt" }, "9", function()
  hs.application.launchOrFocus("Obsidian")
end)

hs.hotkey.bind({ "cmd", "alt" }, "8", function()
  hs.application.launchOrFocus("Brave Browser")
end)

hs.hotkey.bind({ "cmd", "alt" }, "7", function()
  hs.application.launchOrFocus("Messages")
end)

hs.alert.show("Hammerspoon config loaded")
