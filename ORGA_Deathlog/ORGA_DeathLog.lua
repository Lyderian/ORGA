local function ShowDeathLog(frame)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER")
    text:SetText("Guild Death Log Placeholder")
end

-- Create a function to attempt tab registration
local function TryRegisterTab()
    -- Only register the tab if player is in the guild
    if ORGA_RegisterTab and (ORGA_PlayerInGuild == nil or ORGA_PlayerInGuild == true) then
        print("|cFFFFFFFF[ORGA_DeathLog]|r Attempting to register tab")
        ORGA_RegisterTab("Guild Death Log", ShowDeathLog)
        _G.ORGA_DeathLog_Loaded = "Loaded"
    else
        print("|cFFFFFFFF[ORGA_DeathLog]|r Not registering tab - player not in guild or ORGA not loaded")
        _G.ORGA_DeathLog_Loaded = "Loaded but not registered (not in guild)"
    end
end

-- Create an event frame to register when addon is fully loaded
local deathlogFrame = CreateFrame("Frame")
deathlogFrame:RegisterEvent("ADDON_LOADED")
deathlogFrame:RegisterEvent("PLAYER_LOGIN")
deathlogFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "ORGA_DeathLog" then
        print("|cFFFFFFFF[ORGA_DeathLog]|r Module loaded")
        _G.ORGA_DeathLog_Loaded = "Loading"
        
        -- Try and register shortly after loading
        C_Timer.After(2, TryRegisterTab)
        
        -- Only need to handle ADDON_LOADED once
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        -- Try again at login, after ORGA has had time to initialize
        C_Timer.After(3, TryRegisterTab)
        
        -- Only need to handle PLAYER_LOGIN once
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- Create a timer to check for reinitialization requests
C_Timer.NewTicker(1, function()
    if _G.ORGA_DeathLog_TryRegister then
        print("|cFFFFFFFF[ORGA_DeathLog]|r Received reinitialization request")
        _G.ORGA_DeathLog_TryRegister = nil
        TryRegisterTab()
    end
end)
