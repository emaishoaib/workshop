-- modules/vscode.lua
-- VSCode-specific hotkeys (terminal toggle, find & replace)

local VSCODE_IDS = {
    ["com.microsoft.VSCode"] = true,
    ["com.microsoft.VSCodeInsiders"] = true,
}

-- Persist state across reloads
_G.__VSCodeKeybindState = _G.__VSCodeKeybindState or {
    hotkeyBacktick = nil,
    hotkeyH = nil,
    watcher = nil
}

local function isVSCodeFrontmost()
    local app = hs.application.frontmostApplication()
    return app and VSCODE_IDS[app:bundleID()] or false
end

local function enableHotkeys()
    local st = _G.__VSCodeKeybindState

    -- Cmd+` to toggle terminal
    if not st.hotkeyBacktick then
        st.hotkeyBacktick = hs.hotkey.bind({"cmd"}, "`", function()
            local app = hs.application.frontmostApplication()
            if app and VSCODE_IDS[app:bundleID()] then
                app:selectMenuItem({"View", "Terminal"})
            end
        end)
    end

    -- Cmd+H for Find and Replace
    if not st.hotkeyH then
        st.hotkeyH = hs.hotkey.bind({"cmd"}, "h", function()
            local app = hs.application.frontmostApplication()
            if app and VSCODE_IDS[app:bundleID()] then
                hs.eventtap.keyStroke({"cmd", "alt"}, "f")
            end
        end)
    end
end

local function disableHotkeys()
    local st = _G.__VSCodeKeybindState

    if st.hotkeyBacktick then
        st.hotkeyBacktick:delete()
        st.hotkeyBacktick = nil
    end

    if st.hotkeyH then
        st.hotkeyH:delete()
        st.hotkeyH = nil
    end
end

-- Init state
if isVSCodeFrontmost() then enableHotkeys() else disableHotkeys() end

-- App watcher
local st = _G.__VSCodeKeybindState
if not st.watcher then
    st.watcher = hs.application.watcher.new(function(appName, event, app)
        if event == hs.application.watcher.activated then
            if app and VSCODE_IDS[app:bundleID()] then
                enableHotkeys()
            else
                disableHotkeys()
            end
        elseif event == hs.application.watcher.terminated then
            if app and VSCODE_IDS[app:bundleID()] then
                disableHotkeys()
            end
        end
    end)
    st.watcher:start()
end
