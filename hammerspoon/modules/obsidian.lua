-- modules/obsidian.lua
-- Obsidian-specific hotkeys

local OBSIDIAN_ID = "md.obsidian"

-- Persist state across reloads
_G.__ObsidianKeybindState = _G.__ObsidianKeybindState or { hotkeyH = nil, watcher = nil }

local function isObsidianFrontmost()
    local app = hs.application.frontmostApplication()
    return app and app:bundleID() == OBSIDIAN_ID or false
end

local function enableHotkey()
    local st = _G.__ObsidianKeybindState
    if st.hotkeyH then return end
    st.hotkeyH = hs.hotkey.bind({"cmd"}, "h", function()
        local app = hs.application.frontmostApplication()
        if app and app:bundleID() == OBSIDIAN_ID then
            hs.eventtap.keyStroke({"cmd", "alt"}, "f")
        end
    end)
end

local function disableHotkey()
    local st = _G.__ObsidianKeybindState
    if st.hotkeyH then
        st.hotkeyH:delete()
        st.hotkeyH = nil
    end
end

-- Init state
if isObsidianFrontmost() then enableHotkey() else disableHotkey() end

-- App watcher
local st = _G.__ObsidianKeybindState
if not st.watcher then
    st.watcher = hs.application.watcher.new(function(appName, event, app)
        if event == hs.application.watcher.activated then
            if app and app:bundleID() == OBSIDIAN_ID then
                enableHotkey()
            else
                disableHotkey()
            end
        elseif event == hs.application.watcher.terminated then
            if app and app:bundleID() == OBSIDIAN_ID then
                disableHotkey()
            end
        end
    end)
    st.watcher:start()
end
