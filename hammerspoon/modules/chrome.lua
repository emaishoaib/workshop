-- modules/chrome.lua
-- Chrome-specific key interception
-- Note: chromeInterceptor is defined but not started by default.
-- Uncomment the last line to enable it.

local eventtap = hs.eventtap
local eventTypes = eventtap.event.types
local keycodes = hs.keycodes

local function sendInstantKeystroke(mods, key)
    local down = eventtap.event.newKeyEvent(mods, key, true)
    local up = eventtap.event.newKeyEvent(mods, key, false)
    down:post()
    up:post()
end

local chromeInterceptor = eventtap.new({eventTypes.keyDown}, function(event)
    local modifiers = event:getFlags()
    local keyCode = event:getKeyCode()
    local app = hs.application.frontmostApplication()

    if not app or app:name() ~= "Google Chrome" then return false end

    -- Cmd+Shift+I → Option+Cmd+I (DevTools)
    if keyCode == keycodes.map["i"] and modifiers.cmd and modifiers.shift then
        sendInstantKeystroke({"option", "command"}, "i")
        return true
    end

    -- Cmd+H → Cmd+Y (History)
    if keyCode == keycodes.map["h"] and modifiers.cmd and not modifiers.shift then
        sendInstantKeystroke({"command"}, "y")
        return true
    end

    return false
end)

-- chromeInterceptor:start()
