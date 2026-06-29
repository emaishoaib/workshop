-- modules/finder.lua
-- Finder-specific hotkeys and window behaviour

local FINDER_ID = "com.apple.finder"

-- Renamed global to reset stale state from previous shape on reload
_G.__FinderState = _G.__FinderState or { hotkeys = {}, watcher = nil }

local function isFinderFrontmost()
    local app = hs.application.frontmostApplication()
    return app and app:bundleID() == FINDER_ID or false
end

-- Returns the POSIX path of the frontmost Finder window (falls back to Desktop)
local function finderPath()
    local ok, path = hs.osascript.applescript([[
        tell application "Finder"
            if (count of windows) > 0 then
                POSIX path of (target of front window as alias)
            else
                POSIX path of (path to desktop)
            end if
        end tell
    ]])
    return ok and path or nil
end

-- Opens path in iTerm2 (new tab) if installed, otherwise Terminal (new window)
local function openInTerminal(path)
    local escaped = path:gsub("'", "'\\''")
    if hs.application.infoForBundleID("com.googlecode.iterm2") then
        hs.osascript.applescript(string.format([[
            tell application "iTerm"
                activate
                if (count of windows) = 0 then
                    create window with default profile
                else
                    tell current window
                        create tab with default profile
                    end tell
                end if
                tell current session of current window
                    write text "cd '%s'"
                end tell
            end tell
        ]], escaped))
    else
        hs.osascript.applescript(string.format([[
            tell application "Terminal"
                activate
                do script "cd '%s'"
            end tell
        ]], escaped))
    end
end

local function enableHotkeys()
    local st = _G.__FinderState
    if #st.hotkeys > 0 then return end

    -- cmd+return → open selected item (Finder default open)
    st.hotkeys[1] = hs.hotkey.bind({"cmd"}, "return", function()
        local app = hs.application.frontmostApplication()
        if app and app:bundleID() == FINDER_ID then
            hs.eventtap.keyStroke({"cmd"}, "o")
        end
    end)

    -- cmd+shift+t → open current Finder folder in terminal
    st.hotkeys[2] = hs.hotkey.bind({"cmd", "shift"}, "t", function()
        local path = finderPath()
        if path then openInTerminal(path) end
    end)
end

local function disableHotkeys()
    local st = _G.__FinderState
    for _, hk in ipairs(st.hotkeys) do hk:delete() end
    st.hotkeys = {}
end

-- Init
if isFinderFrontmost() then enableHotkeys() else disableHotkeys() end

-- App watcher: enable/disable hotkeys as Finder gains/loses focus
local st = _G.__FinderState
if not st.watcher then
    st.watcher = hs.application.watcher.new(function(appName, event, app)
        if event == hs.application.watcher.activated then
            if app and app:bundleID() == FINDER_ID then
                enableHotkeys()
            else
                disableHotkeys()
            end
        elseif event == hs.application.watcher.terminated then
            if app and app:bundleID() == FINDER_ID then
                disableHotkeys()
            end
        end
    end)
    st.watcher:start()
end

-- Auto-resize Finder window on focus
local finderSizeWatcher = hs.application.watcher.new(function(appName, eventType, app)
    if eventType == hs.application.watcher.activated and appName == "Finder" then
        hs.timer.doAfter(0.1, function()
            local win = hs.window.frontmostWindow()
            if win and win:application():name() == "Finder" then
                win:setSize(hs.geometry.size(1050, 650))
            end
        end)
    end
end)
finderSizeWatcher:start()
