local function ShowEvents(frame)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER")
    text:SetText("Events Placeholder")
end

-- Create a function to attempt tab registration
local function TryRegisterTab()
    -- Only register the tab if player is in the guild
    if ORGA_RegisterTab and (ORGA_PlayerInGuild == nil or ORGA_PlayerInGuild == true) then
        print("|cFFFFFFFF[ORGA_Events]|r Attempting to register tab")
        ORGA_RegisterTab("Events", ShowEvents)
        _G.ORGA_Events_Loaded = "Loaded"
    else
        print("|cFFFFFFFF[ORGA_Events]|r Not registering tab - player not in guild or ORGA not loaded")
        _G.ORGA_Events_Loaded = "Loaded but not registered (not in guild)"
    end
end

-- Create an event frame to register when addon is fully loaded
local eventsFrame = CreateFrame("Frame")
eventsFrame:RegisterEvent("ADDON_LOADED")
eventsFrame:RegisterEvent("PLAYER_LOGIN")
eventsFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "ORGA_Events" then
        print("|cFFFFFFFF[ORGA_Events]|r Module loaded")
        _G.ORGA_Events_Loaded = "Loading"
        
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
    if _G.ORGA_Events_TryRegister then
        print("|cFFFFFFFF[ORGA_Events]|r Received reinitialization request")
        _G.ORGA_Events_TryRegister = nil
        TryRegisterTab()
    end
end)
