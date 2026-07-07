-- modules/hotkeys.lua
-- Global hotkeys that apply system-wide regardless of frontmost app

local eventtap = hs.eventtap
local eventTypes = eventtap.event.types

-- Physical key immediately left of "1" (ISO/ANSI "section"/backtick key).
-- Always reports keyCode 10 regardless of active keyboard layout, unlike
-- the character it produces (e.g. "§" on ISO, "`" on ANSI), which can
-- silently change if the input source is switched. Binding on the raw
-- keyCode instead of the character avoids that layout-dependent flakiness.
local SECTION_KEYCODE = 10

local function sendInstantKeystroke(mods, key)
    local down = eventtap.event.newKeyEvent(mods, key, true)
    local up = eventtap.event.newKeyEvent(mods, key, false)
    down:post()
    up:post()
end

local sectionKeyInterceptor = eventtap.new({eventTypes.keyDown}, function(event)
    if event:getKeyCode() ~= SECTION_KEYCODE then return false end

    local mods = event:getFlags()

    if mods.cmd and not mods.alt and not mods.shift and not mods.ctrl then
        sendInstantKeystroke({"cmd"}, "`")
        return true
    elseif mods.alt and not mods.cmd and not mods.shift and not mods.ctrl then
        sendInstantKeystroke({"alt"}, "`")
        return true
    elseif not mods.cmd and not mods.alt and not mods.shift and not mods.ctrl then
        sendInstantKeystroke({}, "`")
        return true
    end

    return false
end)

sectionKeyInterceptor:start()

-- Lock screen
hs.hotkey.bind({"ctrl"}, "L", function()
    hs.eventtap.keyStroke({"ctrl", "cmd"}, "Q")
end)

-- Media play sound
hs.hotkey.bind({"cmd", "alt"}, "p", function()
    hs.sound.getByName("Glass"):play()
end)
