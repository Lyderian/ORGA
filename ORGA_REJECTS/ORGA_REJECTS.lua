local function ShowRejects(frame)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER")
    text:SetText("REJECTS Placeholder")
end

-- Create a function to attempt tab registration
local function TryRegisterTab()
    -- Only register the tab if player is in the guild
    if ORGA_RegisterTab and (ORGA_PlayerInGuild == nil or ORGA_PlayerInGuild == true) then
        print("|cff9966CC[ORGA_REJECTS]|r Attempting to register tab")
        ORGA_RegisterTab("R.E.J.E.C.T.S", ShowRejects)
        _G.ORGA_REJECTS_Loaded = "Loaded"
    else
        print("|cff9966CC[ORGA_REJECTS]|r Not registering tab - player not in guild or ORGA not loaded")
        _G.ORGA_REJECTS_Loaded = "Loaded but not registered (not in guild)"
    end
end

-- Create an event frame to register when addon is fully loaded
local rejectsFrame = CreateFrame("Frame")
rejectsFrame:RegisterEvent("ADDON_LOADED")
rejectsFrame:RegisterEvent("PLAYER_LOGIN")
rejectsFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "ORGA_REJECTS" then
        print("|cff9966CC[ORGA_REJECTS]|r Module loaded")
        _G.ORGA_REJECTS_Loaded = "Loading"
        
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
    if _G.ORGA_REJECTS_TryRegister then
        print("|cff9966CC[ORGA_REJECTS]|r Received reinitialization request")
        _G.ORGA_REJECTS_TryRegister = nil
        TryRegisterTab()
    end
end)
