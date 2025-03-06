-- ORGA_ORGS Core.lua - Core functionality and initialization

-- Initialize global variables at load time
ORGS_Cart = ORGS_Cart or {}
ORGS_RequestedItems = ORGS_RequestedItems or {}
ORGS_Settings = ORGS_Settings or {
    verboseLogging = false, -- Set to false by default to suppress most chat messages
}

-- Debug print function to control logging
function ORGS_DebugPrint(message, forceShow)
    if forceShow or ORGS_Settings.verboseLogging then
        print(message)
    end
end

-- List of ORGS bank alts
ORGS_BankAlts = {
    ["Orgsdono"] = true,
    ["Orgsdonotwo"] = true,
    ["Orgsonlyfans"] = true
}

-- Format gold into a nice string with colors
function ORGS_FormatGold(amount)
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    return string.format("|cffffd700%dg|r |cffc7c7cf%ds|r |cffeda55f%dc|r", gold, silver, copper)
end

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
            isORGSBankAlt = isBankAlt,
            lastSync = 0 -- Add last sync timestamp
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
                    
                    -- Broadcast inventory update to guild after save
                    if ORGS_Comm and ORGS_Comm.SendInventoryData then
                        C_Timer.After(2, function()
                            ORGS_Comm.SendInventoryData("GUILD")
                        end)
                    end
                    
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
    
    -- Initialize communication module
    C_Timer.After(2, function()
        -- Request inventory sync from guild
        if ORGS_Comm and ORGS_Comm.RequestInventorySync then
            ORGS_Comm.RequestInventorySync()
            print("|cff00ff00[ORGA_ORGS]: Requesting bank inventory data from guild members...|r")
        end
    end)
end

-- Register event handler
local loginFrameEvents = CreateFrame("Frame")
loginFrameEvents:RegisterEvent("PLAYER_LOGIN")
loginFrameEvents:SetScript("OnEvent", OnPlayerLogin)