-- modules/system.lua
-- System-level hotkeys (screenshot, recording)

-- Screenshot
hs.hotkey.bind({"cmd", "alt"}, "s", function()
    hs.eventtap.keyStroke({"cmd", "shift"}, "4")
end)

-- Screen recording
hs.hotkey.bind({"cmd", "alt"}, "r", function()
    hs.eventtap.keyStroke({"cmd", "shift"}, "5")
end)
