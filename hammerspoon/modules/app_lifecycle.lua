-- modules/app_lifecycle.lua
-- App lifecycle management: login restarts and auto-quit rules

-- Restart AltTab and BetterMouse on login to ensure clean state
local function restartLoginApps()
    local function killApp(bundleID)
        local app = hs.application.get(bundleID)
        if app then app:kill() end
    end

    -- killApp("com.lwouis.alt-tab-macos")
    killApp("com.naotanhaocan.BetterMouse")

    hs.timer.doAfter(1, function()
        -- hs.application.launchOrFocusByBundleID("com.lwouis.alt-tab-macos")
        hs.application.launchOrFocusByBundleID("com.naotanhaocan.BetterMouse")
    end)
end

-- Auto-quit Microsoft AutoUpdate whenever it launches
_G.__AutoUpdateWatcher = _G.__AutoUpdateWatcher or hs.application.watcher.new(function(appName, event, app)
    if event == hs.application.watcher.launched then
        if app and app:bundleID() == "com.microsoft.autoupdate2" then
            app:kill()
        end
    end
end)
_G.__AutoUpdateWatcher:start()

restartLoginApps()
