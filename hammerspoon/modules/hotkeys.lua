-- modules/hotkeys.lua
-- Global hotkeys that apply system-wide regardless of frontmost app

-- Bind "§" to "`"
hs.hotkey.bind({}, "§", function()
    hs.eventtap.keyStroke({}, "`")
end)

-- Bind "Cmd + §" to "Cmd + `"
hs.hotkey.bind({"cmd"}, "§", function()
    hs.eventtap.keyStroke({"cmd"}, "`")
end)

-- Bind "Alt + §" to "Alt + `"
hs.hotkey.bind({"alt"}, "§", function()
    hs.eventtap.keyStroke({"alt"}, "`")
end)

-- Lock screen
hs.hotkey.bind({"ctrl"}, "L", function()
    hs.eventtap.keyStroke({"ctrl", "cmd"}, "Q")
end)

-- Media play sound
hs.hotkey.bind({"cmd", "alt"}, "p", function()
    hs.sound.getByName("Glass"):play()
end)
