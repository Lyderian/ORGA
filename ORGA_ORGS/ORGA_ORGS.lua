-- ORGA_ORGS main file
-- Main loader file that handles module loading

-- Initialize data tables
ORGS_Cart = ORGS_Cart or {}
ORGS_RequestedItems = ORGS_RequestedItems or {}
ORGS_Settings = ORGS_Settings or {
    verboseLogging = false -- Set to false by default to suppress most chat messages
}

-- List of ORGS bank alts
ORGS_BankAlts = {
    ["Orgsdono"] = true,
    ["Orgsdonotwo"] = true,
    ["Orgsonlyfans"] = true
}

-- Print loaded bank alts for debugging
print("|cFFFFFFFF[ORGA_ORGS]|r Initializing with bank alts:")
for name, _ in pairs(ORGS_BankAlts) do
    print("   - " .. name)
end

-- Debug print function to control logging
function ORGS_DebugPrint(message, forceShow)
    if forceShow or ORGS_Settings.verboseLogging then
        print(message)
    end
end

-- Format gold into a nice string with colors
function ORGS_FormatGold(amount)
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    return string.format("|cffffd700%dg|r |cffc7c7cf%ds|r |cffeda55f%dc|r", gold, silver, copper)
end

-- Function to attempt tab registration
local function TryRegisterTabs()
    -- Only register if player is in the guild or guild check isn't implemented yet
    if ORGA_RegisterTab and (ORGA_PlayerInGuild == nil or ORGA_PlayerInGuild == true) then
        print("|cFFFFFFFF[ORGA_ORGS]|r Attempting to register ORGS tab")
        ORGA_RegisterTab("ORGS", ORGS_ShowInventoryUI)
        
        -- Add a way for bank alts to view requests
        local playerName = UnitName("player")
        if ORGS_BankAlts and ORGS_BankAlts[playerName] then
            print("|cFFFFFFFF[ORGA_ORGS]|r Attempting to register ORGS Requests tab for bank alt: " .. playerName)
            ORGA_RegisterTab("ORGS Requests", ORGS_ShowRequestsUI)
        end
        
        _G.ORGA_ORGS_Loaded = "Loaded"
    else
        print("|cFFFFFFFF[ORGA_ORGS]|r Not registering tabs - player not in guild or ORGA not loaded")
        _G.ORGA_ORGS_Loaded = "Loaded but not registered (not in guild)"
    end
end

-- Register tab with main addon
local function InitializeAddon()
    -- Mark that we're starting to load
    _G.ORGA_ORGS_Loaded = "Loading"
    
    -- Need to wait until the main ORGA addon is fully initialized
    C_Timer.After(2, TryRegisterTabs)
end

-- Create a timer to check for reinitialization requests
C_Timer.NewTicker(1, function()
    if _G.ORGA_ORGS_TryRegister then
        print("|cFFFFFFFF[ORGA_ORGS]|r Received reinitialization request")
        _G.ORGA_ORGS_TryRegister = nil
        TryRegisterTabs()
    end
end)

-- Define slash commands
SLASH_ORGASAVE1 = "/orgasave"
SlashCmdList["ORGASAVE"] = function()
    ORGS_SaveInventoryData()
    print("|cff00ff00[ORGA_ORGS]: Manual save triggered.|r")
end

-- Command to toggle verbose logging
SLASH_ORGSVERBOSE1 = "/orgsverbose"
SlashCmdList["ORGSVERBOSE"] = function()
    ORGS_Settings.verboseLogging = not ORGS_Settings.verboseLogging
    local state = ORGS_Settings.verboseLogging and "ON" or "OFF"
    print("|cff00ff00[ORGA_ORGS]: Verbose logging " .. state .. "|r")
end

-- Bank alt detection and UI adjustment
local function OnPlayerLogin()
    local playerName = UnitName("player")
    local isBankAlt = ORGS_BankAlts[playerName] or false
    
    -- Initialize data if needed
    if not ORGA_Data then
        ORGA_Data = {}
    end
    
    if not ORGA_Data[playerName] then
        ORGA_Data[playerName] = {
            inventory = {},
            gold = GetMoney(),
            isORGSBankAlt = isBankAlt
        }
    end
    
    -- Auto-scan bank when a bank alt opens their bank
    if isBankAlt then
        -- Create a frame to monitor bank open events
        local bankOpenFrameEvents = CreateFrame("Frame")
        
        -- Register only the standard bank event
        bankOpenFrameEvents:RegisterEvent("BANKFRAME_OPENED")
        
        -- Set up event handler
        bankOpenFrameEvents:SetScript("OnEvent", function(self, event)
            print("|cff00ff00[ORGA_ORGS]: Bank opened event detected...|r")
            print("|cff00ff00[ORGA_ORGS]: Bank opened, automatically scanning inventory in 2 seconds...|r")
            
            -- Add save button to bank frame - try immediately and again after delay
            ORGS_AddSaveButtonToBankFrame()
            
            -- Use a timer to check periodically for bank being open
            local attempts = 0
            local maxAttempts = 10
            local checkInterval = 0.5 -- check every 0.5 seconds
            
            local function checkBankAndScan()
                attempts = attempts + 1
                
                -- Try to add button again
                ORGS_AddSaveButtonToBankFrame()
                
                -- Check if bank is actually open before scanning
                if ORGS_IsBankOpen() then
                    print("|cff00ff00[ORGA_ORGS]: Bank confirmed open on attempt " .. attempts .. ", scanning inventory...|r")
                    ORGS_SaveInventoryData()
                    return -- Success, no need for more attempts
                elseif attempts < maxAttempts then
                    -- Try again after delay
                    C_Timer.After(checkInterval, checkBankAndScan)
                else
                    print("|cffff0000[ORGA_ORGS]: Bank frame not detected as open after " .. attempts .. " attempts, scan aborted.|r")
                end
            end
            
            -- Start checking after an initial delay
            C_Timer.After(0.5, checkBankAndScan)
        end)
    end
    
    -- Initialize UI
    InitializeAddon()
end

-- Register event handler
local loginFrameEvents = CreateFrame("Frame")
loginFrameEvents:RegisterEvent("PLAYER_LOGIN")
loginFrameEvents:SetScript("OnEvent", OnPlayerLogin)