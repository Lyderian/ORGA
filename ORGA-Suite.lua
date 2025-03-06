-- ORGA-Suite Loader
-- This file exists to make the addon loadable through CurseForge App

-- Print version information on load
local function PrintVersion()
    print("|cff00FF00ORGA Suite v1.0.11|r - Only Rejects Guild Addon Suite loaded successfully.")
    print("|cff00FF00ORGA Suite|r - Use /orga to open the main window")
end

-- Create frame to handle load event
local loaderFrame = CreateFrame("Frame")
loaderFrame:RegisterEvent("PLAYER_LOGIN")
loaderFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Wait a bit to let all modules initialize first
        C_Timer.After(2, PrintVersion)
    end
end)