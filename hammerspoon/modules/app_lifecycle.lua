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

-- Restart BetterMouse on wake from sleep
_G.__SleepWatcher = _G.__SleepWatcher or hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.systemDidWake
    or event == hs.caffeinate.watcher.screensDidWake then
        restartLoginApps()
    end
end)
_G.__SleepWatcher:start()

-- Restart BetterMouse when a mouse is connected (USB or Bluetooth HID)
-- macOS surfaces Bluetooth HID devices through IOKit, so hs.usb.watcher catches both.
-- If mouse has a branded name (e.g. "MX Master 3S"), add it to the list below.
local mouseKeywords = { "mouse", "trackball", "mx master 3s" }
_G.__UsbMouseWatcher = _G.__UsbMouseWatcher or hs.usb.watcher.new(function(device)
    if device.eventType ~= "added" then return end
    local name = (device.productName or ""):lower()
    for _, keyword in ipairs(mouseKeywords) do
        if name:find(keyword, 1, true) then
            hs.timer.doAfter(1.5, restartLoginApps)
            return
        end
    end
end)
_G.__UsbMouseWatcher:start()

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
