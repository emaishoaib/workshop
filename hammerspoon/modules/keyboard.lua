-- modules/keyboard.lua
-- Swap the § key (left of 1) with the ` key (left of Z) on the ISO keyboard

-- Matches only the MacBook's built-in keyboard, so external keyboards are left alone
local swapCommand = [[hidutil property --matching '{"VendorID":0x5ac,"ProductID":0x343}' --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000064,"HIDKeyboardModifierMappingDst":0x700000035},{"HIDKeyboardModifierMappingSrc":0x700000035,"HIDKeyboardModifierMappingDst":0x700000064}]}']]

local function applyKeySwap()
    hs.execute(swapCommand)
end

-- Re-apply on wake, in case macOS drops the mapping during sleep
_G.__KeySwapWakeWatcher = _G.__KeySwapWakeWatcher or hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.systemDidWake then
        applyKeySwap()
    end
end)
_G.__KeySwapWakeWatcher:start()

applyKeySwap()
