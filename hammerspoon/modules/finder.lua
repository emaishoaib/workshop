-- modules/finder.lua
-- Finder-specific hotkeys and window behaviour

local FINDER_ID = "com.apple.finder"

-- Persist state across reloads
_G.__FinderKeybindState = _G.__FinderKeybindState or { hotkeyReturn = nil, watcher = nil }

local function isFinderFrontmost()
    local app = hs.application.frontmostApplication()
    return app and app:bundleID() == FINDER_ID or false
end

local function enableHotkey()
    local st = _G.__FinderKeybindState
    if st.hotkeyReturn then return end
    st.hotkeyReturn = hs.hotkey.bind({"cmd"}, "return", function()
        local app = hs.application.frontmostApplication()
        if app and app:bundleID() == FINDER_ID then
            hs.eventtap.keyStroke({"cmd"}, "o")
        end
    end)
end

local function disableHotkey()
    local st = _G.__FinderKeybindState
    if st.hotkeyReturn then
        st.hotkeyReturn:delete()
        st.hotkeyReturn = nil
    end
end

-- Init state
if isFinderFrontmost() then enableHotkey() else disableHotkey() end

-- App watcher
local st = _G.__FinderKeybindState
if not st.watcher then
    st.watcher = hs.application.watcher.new(function(appName, event, app)
        if event == hs.application.watcher.activated then
            if app and app:bundleID() == FINDER_ID then
                enableHotkey()
            else
                disableHotkey()
            end
        elseif event == hs.application.watcher.terminated then
            if app and app:bundleID() == FINDER_ID then
                disableHotkey()
            end
        end
    end)
    st.watcher:start()
end

-- Auto-resize Finder window on focus
local finderWatcher = hs.application.watcher.new(function(appName, eventType, app)
    if eventType == hs.application.watcher.activated and appName == "Finder" then
        hs.timer.doAfter(0.1, function()
            local win = hs.window.frontmostWindow()
            if win and win:application():name() == "Finder" then
                win:setSize(hs.geometry.size(1050, 650))
            end
        end)
    end
end)
finderWatcher:start()
