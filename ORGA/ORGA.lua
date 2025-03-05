-- Addon version information
ORGA_VERSION = {
    major = 1,
    minor = 0,
    patch = 1,
    build = 20250304,  -- YYYYMMDD format
}
ORGA_VERSION_STRING = ORGA_VERSION.major .. "." .. ORGA_VERSION.minor .. "." .. ORGA_VERSION.patch

-- Initialize saved variables if not exists
if not ORGA_WindowSettings then
    ORGA_WindowSettings = {
        width = 520,
        height = 420,
        point = "CENTER",
        xOfs = 0,
        yOfs = 0,
        minimapPos = 45, -- Default position on minimap (45 degrees)
        version = ORGA_VERSION_STRING -- Store version in saved variables
    }
else
    -- Update version in saved variables
    ORGA_WindowSettings.version = ORGA_VERSION_STRING
end

-- Function to check if player is in the guild "OnlyRejects"
local function IsInOnlyRejectsGuild()
    -- In Classic, just use the original IsInGuild API but make sure to not call our own function
    if _G.IsInGuild() then -- Use global _G.IsInGuild to ensure we're calling the API function
        local guildName = GetGuildInfo("player")
        
        -- Make this check more lenient - guild name might have different capitalization
        if guildName then
            -- Case insensitive comparison to handle capitalization differences
            return string.lower(guildName) == string.lower("OnlyRejects")
        end
    end
    return false
end

-- Global variable to track guild membership
ORGA_PlayerInGuild = false

-- Variable to store guild members (for non-guild member UI)
ORGA_GuildMembers = {}

-- Table to track invite request cooldowns
ORGA_InviteRequestCooldowns = {}

-- Flag to track if a search has been performed
ORGA_HasSearchedForMembers = false

-- Create the main ORGA frame
local ORGA = CreateFrame("Frame", "ORGAMainFrame", UIParent, "BackdropTemplate")
ORGA:SetSize(ORGA_WindowSettings.width, ORGA_WindowSettings.height)
ORGA:SetPoint(ORGA_WindowSettings.point, UIParent, ORGA_WindowSettings.point, ORGA_WindowSettings.xOfs, ORGA_WindowSettings.yOfs)

-- Make ORGA global so other addons can access it
_G.ORGAMainFrame = ORGA

-- Set up whisper handling for auto-invite
ORGA:RegisterEvent("CHAT_MSG_WHISPER")
ORGA:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_WHISPER" then
        local message, sender = ...
        -- Strip realm name if present
        sender = string.match(sender, "([^-]+)")
        
        -- Check if it's an invite request message
        if message:find("invite me") or 
           message:find("join the Only Rejects guild") or 
           message:find("join the OnlyRejects guild") or
           message:find("invite to guild") or
           message:find("invite to OnlyRejects") then
            
            -- Check if player is in guild and can invite
            if ORGA_PlayerInGuild and CanGuildInvite() then
                print("|cff9966CC[ORGA]|r Received invite request from " .. sender .. ", sending guild invite...")
                GuildInvite(sender)
                SendChatMessage("I've sent you a guild invite. Welcome to OnlyRejects!", "WHISPER", nil, sender)
            end
        end
    end
end)

-- WoW Classic doesn't fully support frame resizing, so we need a simpler approach
-- Remove SetResizable and SetMinResize calls

-- Add a black background frame behind the main ORGA frame
local backgroundFrame = CreateFrame("Frame", nil, ORGA, "BackdropTemplate")
backgroundFrame:SetAllPoints(ORGA)
backgroundFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", -- Black background
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 512, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})

-- Add the centered, resized image on top of the black background
-- Create this BEFORE the resize handle to fix the reference issue
local backgroundTexture = ORGA:CreateTexture(nil, "ARTWORK")
backgroundTexture:SetTexture("Interface\\AddOns\\ORGA\\Textures\\background.tga")
backgroundTexture:SetPoint("CENTER", ORGA, "CENTER", 0, 0)
backgroundTexture:SetSize(ORGA:GetWidth() - 40, ORGA:GetHeight() - 40)

-- Create resize handle in the bottom right corner using a manual resize approach for Classic
local resizeHandle = CreateFrame("Button", nil, ORGA)
resizeHandle:SetSize(16, 16)
resizeHandle:SetPoint("BOTTOMRIGHT", ORGA, "BOTTOMRIGHT", 0, 0)
resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

-- Variables to track resize state
local isResizing = false
local initialCursorX, initialCursorY, initialWidth, initialHeight

resizeHandle:SetScript("OnMouseDown", function()
    isResizing = true
    initialCursorX, initialCursorY = GetCursorPosition()
    initialWidth, initialHeight = ORGA:GetWidth(), ORGA:GetHeight()
    resizeHandle:SetScript("OnUpdate", function()
        if isResizing then
            local currentCursorX, currentCursorY = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            
            -- Calculate width/height change based on cursor movement
            local widthChange = (currentCursorX - initialCursorX) / scale
            local heightChange = (initialCursorY - currentCursorY) / scale  -- Y is inverted
            
            -- Apply the new size with minimum constraints
            local newWidth = math.max(420, initialWidth + widthChange)
            local newHeight = math.max(380, initialHeight + heightChange)
            
            ORGA:SetSize(newWidth, newHeight)
            
            -- Adjust the background texture size (using the correct reference)
            backgroundTexture:SetSize(newWidth - 40, newHeight - 40)
        end
    end)
end)

resizeHandle:SetScript("OnMouseUp", function()
    isResizing = false
    resizeHandle:SetScript("OnUpdate", nil)
    
    -- Save window size
    ORGA_WindowSettings.width = ORGA:GetWidth()
    ORGA_WindowSettings.height = ORGA:GetHeight()
end)

-- Ensure ORGA is managed independently from Blizzard UI
ORGA:SetMovable(true)
ORGA:EnableMouse(true)
ORGA:RegisterForDrag("LeftButton")
ORGA:SetScript("OnDragStart", ORGA.StartMoving)
ORGA:SetScript("OnDragStop", function()
    ORGA:StopMovingOrSizing()
    
    -- Save window position
    local point, _, _, xOfs, yOfs = ORGA:GetPoint()
    ORGA_WindowSettings.point = point
    ORGA_WindowSettings.xOfs = xOfs
    ORGA_WindowSettings.yOfs = yOfs
end)

-- Secure Execution Wrapper to prevent conflicts
local function SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        print("|cffff0000[ORGA Error]:|r", result)
    end
    return result
end

-- Table to store registered tabs
ORGA_Tabs = {}

-- Function for other addons to register tabs
function ORGA_RegisterTab(name, onSelect)
    print("|cff9966CC[ORGA]|r Registering tab: " .. name)
    
    -- Check if a tab with this name already exists to prevent duplicates
    for i, tab in ipairs(ORGA_Tabs) do
        if tab.name == name then
            print("|cff9966CC[ORGA]|r Skipping duplicate tab: " .. name)
            return
        end
    end
    
    table.insert(ORGA_Tabs, { name = name, onSelect = onSelect })
end

-- Function to initialize and display tab buttons
local function InitializeTabs()
    local tabFrames = {}
    local tabButtons = {}

    -- Add a close button
    local closeButton = CreateFrame("Button", nil, ORGA, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", ORGA, "TOPRIGHT", 0, 0)
    closeButton:SetScript("OnClick", function()
        ORGA:Hide()
    end)

    for i, tabData in ipairs(ORGA_Tabs) do
        local tabButton = CreateFrame("Button", nil, ORGA, "UIPanelButtonTemplate")
        
        -- Adjust tab width based on number of tabs
        local numTabs = #ORGA_Tabs
        local maxWidth = math.min(520, ORGA:GetWidth()) - 30 -- account for margins
        local buttonWidth = math.max(80, math.floor(maxWidth / numTabs) - 10)
        local totalButtonsWidth = buttonWidth * numTabs + (numTabs - 1) * 5
        local startX = (ORGA:GetWidth() - totalButtonsWidth) / 2
        
        tabButton:SetSize(buttonWidth, 28)
        tabButton:SetPoint("TOPLEFT", ORGA, "TOPLEFT", startX + (i - 1) * (buttonWidth + 5), -40)
        tabButton:SetText(tabData.name)
        tabButton:SetNormalFontObject("GameFontHighlight")
        tabButton:GetFontString():SetTextColor(0.7, 0.3, 1)
        
        -- Automatically adjust text size to fit the button
        local fontName, fontHeight, fontFlags = tabButton:GetFontString():GetFont()
        local textWidth = tabButton:GetFontString():GetStringWidth()
        
        -- Scale down text if it's too wide for the button
        if textWidth > (buttonWidth - 10) then
            local scaleFactor = (buttonWidth - 10) / textWidth
            local newFontSize = math.max(8, math.floor(fontHeight * scaleFactor))
            tabButton:GetFontString():SetFont(fontName, newFontSize, fontFlags)
        end
        
        table.insert(tabButtons, tabButton)

        local tabFrame = CreateFrame("Frame", nil, ORGA)
        tabFrame:SetWidth(ORGA:GetWidth() - 60)
        tabFrame:SetHeight(ORGA:GetHeight() - 100)
        tabFrame:SetPoint("BOTTOM", ORGA, "BOTTOM", 0, 10)
        tabFrame:Hide()

        tabFrames[i] = tabFrame

        tabButton:SetScript("OnClick", function()
            for _, frame in pairs(tabFrames) do frame:Hide() end
            tabFrame:Show()
            if tabData.onSelect then tabData.onSelect(tabFrame) end
        end)

        if i == 1 then
            tabFrame:Show()
        end
    end
    
    -- When the ORGA frame size changes, we need to update tab frames and buttons
    ORGA:HookScript("OnSizeChanged", function(self, width, height)
        -- Update tab frames size
        for _, frame in pairs(tabFrames) do
            frame:SetWidth(width - 60)
            frame:SetHeight(height - 100)
        end
        
        -- Reposition tab buttons
        local numTabs = #tabButtons
        local maxWidth = math.min(520, width) - 30
        local buttonWidth = math.max(80, math.floor(maxWidth / numTabs) - 10)
        local totalButtonsWidth = buttonWidth * numTabs + (numTabs - 1) * 5
        local startX = (width - totalButtonsWidth) / 2
        
        for i, button in ipairs(tabButtons) do
            button:SetWidth(buttonWidth)
            button:SetPoint("TOPLEFT", ORGA, "TOPLEFT", startX + (i - 1) * (buttonWidth + 5), -40)
            
            -- Update text size to fit new button width
            local fontName, fontHeight, fontFlags = button:GetFontString():GetFont()
            local textWidth = button:GetFontString():GetStringWidth()
            
            -- Reset font to original size first
            button:GetFontString():SetFont(fontName, 10, fontFlags)
            
            -- Then scale down if needed
            textWidth = button:GetFontString():GetStringWidth()
            if textWidth > (buttonWidth - 10) then
                local scaleFactor = (buttonWidth - 10) / textWidth
                local newFontSize = math.max(8, math.floor(10 * scaleFactor))
                button:GetFontString():SetFont(fontName, newFontSize, fontFlags)
            end
        end
    end)
end

-- Create guest tab for non-guild members
local function CreateGuestTab()
    -- Clear any existing tabs
    ORGA_Tabs = {}
    
    -- Register guest tab
    ORGA_RegisterTab("Guild Invite", function(frame)
        -- Clear the frame
        for _, child in pairs({frame:GetChildren()}) do
            child:Hide()
        end
        
        -- Add message
        local message = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        message:SetPoint("TOP", frame, "TOP", 0, -20)
        message:SetWidth(frame:GetWidth() - 40)
        message:SetJustifyH("CENTER")
        message:SetText("You do not appear to be in the OnlyRejects guild.\nClick the \"Request Invite\" button next to any online guild member below for a guild invitation.")
        message:SetTextColor(1, 0.82, 0)
        
        -- Create scrollframe for member list
        local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", message, "BOTTOMLEFT", 0, -20)
        scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)
        
        local content = CreateFrame("Frame", nil, scrollFrame)
        content:SetSize(scrollFrame:GetWidth(), 500) -- Initial height, will adjust
        scrollFrame:SetScrollChild(content)
        
        -- Add /who button
        local whoButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        whoButton:SetSize(160, 22) -- Made button wider to fit text
        whoButton:SetPoint("TOP", message, "BOTTOM", 0, -5)
        whoButton:SetText("Search for Members")
        whoButton:SetScript("OnClick", function()
            -- Use a simpler slash command format without g: prefix that might cause issues
            SlashCmdList["WHO"]("OnlyRejects")
            print("|cff9966CC[ORGA]|r Searching for OnlyRejects guild members...")
            
            -- Set flag that a search has been performed
            ORGA_HasSearchedForMembers = true
            
            -- Disable button temporarily
            whoButton:SetEnabled(false)
            C_Timer.After(5, function() whoButton:SetEnabled(true) end)
        end)
        
        -- Function to update member list
        local function UpdateMemberList()
            -- Clear existing entries
            for _, child in pairs({content:GetChildren()}) do
                child:Hide()
            end
            
            local yOffset = 10
            local memberCount = 0
            
            -- Helper function to count table entries
            local function tcount(t)
                local count = 0
                for _ in pairs(t) do count = count + 1 end
                return count
            end
            
            -- For debugging
            print("|cff9966CC[ORGA]|r Updating member list, members found: " .. (ORGA_GuildMembers and tcount(ORGA_GuildMembers) or 0))
            
            -- Sort members alphabetically
            local sortedMembers = {}
            for name, info in pairs(ORGA_GuildMembers) do
                table.insert(sortedMembers, {name = name, info = info})
            end
            table.sort(sortedMembers, function(a, b) return a.name < b.name end)
            
            -- Add entry for each member
            for _, memberData in ipairs(sortedMembers) do
                local name = memberData.name
                local info = memberData.info
                
                local memberFrame = CreateFrame("Frame", nil, content)
                memberFrame:SetSize(content:GetWidth() - 20, 25)
                memberFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -yOffset)
                
                local nameText = memberFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                nameText:SetPoint("LEFT", memberFrame, "LEFT", 5, 0)
                nameText:SetText(name)
                
                -- Color by class if available
                if info.class then
                    local classColor = RAID_CLASS_COLORS[info.class]
                    if classColor then
                        nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
                    end
                end
                
                -- Create request invite button if not on cooldown
                local isCooldown = ORGA_InviteRequestCooldowns[name] and 
                    (GetTime() - ORGA_InviteRequestCooldowns[name] < 300) -- 5 minute cooldown
                
                if isCooldown then
                    local statusText = memberFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    statusText:SetPoint("RIGHT", memberFrame, "RIGHT", -5, 0)
                    statusText:SetText("Request Sent")
                    statusText:SetTextColor(0.5, 0.5, 0.5)
                else
                    local requestButton = CreateFrame("Button", nil, memberFrame, "UIPanelButtonTemplate")
                    requestButton:SetSize(100, 20)
                    requestButton:SetPoint("RIGHT", memberFrame, "RIGHT", -5, 0)
                    requestButton:SetText("Request Invite")
                    requestButton:SetScript("OnClick", function()
                        -- Send whisper to player 
                        SendChatMessage("Hello! I'd like to join the OnlyRejects guild. Could you please invite me?", "WHISPER", nil, name)
                        -- Update cooldown
                        ORGA_InviteRequestCooldowns[name] = GetTime()
                        -- Update UI
                        UpdateMemberList()
                    end)
                end
                
                yOffset = yOffset + 30
                memberCount = memberCount + 1
            end
            
            -- Update content height
            content:SetHeight(math.max(scrollFrame:GetHeight(), memberCount * 30 + 20))
            
            -- Show a message only if a search was performed and no members found
            if memberCount == 0 and ORGA_HasSearchedForMembers then
                local noMembersText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                noMembersText:SetPoint("CENTER", content, "CENTER", 0, 0)
                noMembersText:SetText("No guild members found online.")
                noMembersText:SetTextColor(0.7, 0.7, 0.7)
            end
        end
        
        -- Create event frame to catch WHO results
        local whoEventFrame = CreateFrame("Frame")
        whoEventFrame:RegisterEvent("WHO_LIST_UPDATE")
        whoEventFrame:SetScript("OnEvent", function(self, event)
            if event == "WHO_LIST_UPDATE" and ORGA_HasSearchedForMembers then
                -- In WoW Classic, the C_FriendList API might not be available
                -- Check if we have the C_FriendList API first
                if C_FriendList and C_FriendList.GetNumWhoResults then
                    -- Use the new API
                    local numWhos = C_FriendList.GetNumWhoResults()
                    for i = 1, numWhos do
                        local info = C_FriendList.GetWhoInfo(i)
                        -- Debug WHO results
                        print("|cff9966CC[ORGA]|r WHO result: " .. info.fullName .. " - Guild: " .. (info.fullGuildName or "None"))
                        
                        -- Check for guild match
                        if info and info.fullGuildName and 
                           string.find(info.fullGuildName, "OnlyRejects") then
                            print("|cff9966CC[ORGA]|r Found guild member: " .. info.fullName)
                            ORGA_GuildMembers[info.fullName] = {
                                class = info.filename, -- Normalized class name for coloring
                                level = info.level
                            }
                        end
                    end
                else
                    -- Fallback to the classic API
                    local numWhos = GetNumWhoResults()
                    for i = 1, numWhos do
                        local name, guild, level, race, class = GetWhoInfo(i)
                        -- Debug WHO results
                        print("|cff9966CC[ORGA]|r WHO result: " .. name .. " - Guild: " .. (guild or "None"))
                        
                        -- Check for guild match
                        if guild and string.find(guild, "OnlyRejects") then
                            print("|cff9966CC[ORGA]|r Found guild member: " .. name)
                            ORGA_GuildMembers[name] = {
                                class = string.upper(class), -- Normalize the class name
                                level = level
                            }
                        end
                    end
                end
                UpdateMemberList()
            end
        end)
        
        -- Initial update
        UpdateMemberList()
    end)
    
    -- Initialize tabs
    InitializeTabs()
end

-- Function to create the debug panel as a separate frame
local function CreateDebugPanel()
    -- Create a separate frame for debugging
    local debugFrame = CreateFrame("Frame", "ORGADebugFrame", UIParent, "BackdropTemplate")
    debugFrame:SetSize(400, 400)
    debugFrame:SetPoint("CENTER")
    debugFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    debugFrame:SetMovable(true)
    debugFrame:EnableMouse(true)
    debugFrame:RegisterForDrag("LeftButton")
    debugFrame:SetScript("OnDragStart", debugFrame.StartMoving)
    debugFrame:SetScript("OnDragStop", debugFrame.StopMovingOrSizing)
    debugFrame:Hide()
    
    -- Add title text
    local title = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("ORGA Debug Information")
    
    -- Create close button
    local closeButton = CreateFrame("Button", nil, debugFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    
    -- Create debug info text
    local debugInfo = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugInfo:SetPoint("TOPLEFT", 20, -50)
    debugInfo:SetWidth(360)
    debugInfo:SetJustifyH("LEFT")
    
    -- Add refresh button
    local refreshButton = CreateFrame("Button", nil, debugFrame, "UIPanelButtonTemplate")
    refreshButton:SetSize(120, 26)
    refreshButton:SetPoint("BOTTOMLEFT", 20, 15)
    refreshButton:SetText("Reinitialize")
    
    -- Add copy button
    local copyButton = CreateFrame("Button", nil, debugFrame, "UIPanelButtonTemplate")
    copyButton:SetSize(120, 26)
    copyButton:SetPoint("BOTTOMRIGHT", -20, 15)
    copyButton:SetText("Copy Info")
    
    -- Create a backdrop frame and an editbox on top of it
    local clipboardBackdrop = CreateFrame("Frame", nil, debugFrame, "BackdropTemplate")
    clipboardBackdrop:SetSize(350, 25)
    clipboardBackdrop:SetPoint("CENTER")
    clipboardBackdrop:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    clipboardBackdrop:SetBackdropColor(0, 0, 0, 0.8)
    clipboardBackdrop:Hide()
    
    -- Create editbox for clipboard functionality
    local clipboardEditBox = CreateFrame("EditBox", nil, clipboardBackdrop)
    clipboardEditBox:SetSize(340, 20)
    clipboardEditBox:SetPoint("CENTER", clipboardBackdrop, "CENTER", 0, 0)
    clipboardEditBox:SetMultiLine(true)
    clipboardEditBox:SetAutoFocus(true)
    clipboardEditBox:SetFontObject(GameFontHighlight)
    
    -- Close on escape
    clipboardEditBox:SetScript("OnEscapePressed", function(self) 
        clipboardBackdrop:Hide() 
    end)
    
    -- Add instructions text
    local clipboardInstructions = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    clipboardInstructions:SetPoint("BOTTOM", clipboardBackdrop, "TOP", 0, 5)
    clipboardInstructions:SetText("Press Ctrl+C to copy, then Esc to close")
    clipboardInstructions:Hide()
    
    -- Show/hide instructions with the backdrop
    clipboardBackdrop:SetScript("OnShow", function() clipboardInstructions:Show() end)
    clipboardBackdrop:SetScript("OnHide", function()
        clipboardInstructions:Hide()
        debugFrame:SetAlpha(1.0) -- Restore opacity when done
    end)
    
    -- Update the debug info
    local function UpdateDebugInfo()
        local infoLines = {}
        table.insert(infoLines, "====== ORGA Debug Information ======")
        table.insert(infoLines, "ORGA Version: " .. ORGA_VERSION_STRING .. " (build " .. ORGA_VERSION.build .. ")")
        table.insert(infoLines, "WoW Version: " .. (GetBuildInfo and GetBuildInfo() or "Unknown"))
        table.insert(infoLines, "Time: " .. date("%Y-%m-%d %H:%M:%S"))
        table.insert(infoLines, "")
        table.insert(infoLines, "Guild Status: " .. (ORGA_PlayerInGuild and "In Guild" or "Not In Guild"))
        table.insert(infoLines, "")
        table.insert(infoLines, "Module Registration Status:")
        
        -- Check if modules are loaded at all (check TOC dependencies working)
        local moduleStatus = {
            ORGA_DeathLog = _G.ORGA_DeathLog_Loaded or "Not Loaded",
            ORGA_Events = _G.ORGA_Events_Loaded or "Not Loaded",
            ORGA_ORGS = _G.ORGA_ORGS_Loaded or "Not Loaded",
            ORGA_REJECTS = _G.ORGA_REJECTS_Loaded or "Not Loaded"
        }
        
        for module, status in pairs(moduleStatus) do
            table.insert(infoLines, "- " .. module .. ": " .. status)
        end
        
        table.insert(infoLines, "")
        table.insert(infoLines, "Tabs loaded: " .. #ORGA_Tabs)
        for i, tab in ipairs(ORGA_Tabs) do
            table.insert(infoLines, "- " .. tab.name)
        end
        
        table.insert(infoLines, "")
        table.insert(infoLines, "====================================")
        
        -- Join for display
        local displayText = table.concat(infoLines, "\n")
        debugInfo:SetText(displayText)
        
        -- Store for clipboard
        clipboardEditBox.fullText = displayText
    end
    
    -- Set up copy button
    copyButton:SetScript("OnClick", function()
        if clipboardEditBox.fullText then
            clipboardEditBox:SetText(clipboardEditBox.fullText)
            clipboardBackdrop:Show()
            clipboardEditBox:HighlightText()
            clipboardEditBox:SetFocus()
            C_Timer.After(0.1, function() 
                debugFrame:SetAlpha(0.5) -- Dim the main window while copying
            end)
        end
    end)
    
    -- Set up refresh button
    refreshButton:SetScript("OnClick", function()
        print("|cff9966CC[ORGA]|r Manually reinitializing addon...")
        -- Force reinitialize modules
        for _, m in ipairs({"ORGA_DeathLog", "ORGA_Events", "ORGA_ORGS", "ORGA_REJECTS"}) do
            print("|cff9966CC[ORGA]|r Re-calling module registration for " .. m)
            -- Signal modules to try registering again
            _G[m .. "_TryRegister"] = true
        end
        
        -- Update after a short delay
        C_Timer.After(1, UpdateDebugInfo)
    end)
    
    -- Add slash command to show the debug panel
    SLASH_ORGADEBUG1 = "/orgadebug"
    SlashCmdList["ORGADEBUG"] = function()
        UpdateDebugInfo()
        debugFrame:Show()
    end
    
    return debugFrame
end

-- Debug panel reference
local debugPanel

-- Function to check guild status and initialize appropriate UI
local function InitializeAddon()
    -- Check if player is in the guild
    ORGA_PlayerInGuild = IsInOnlyRejectsGuild()
    
    -- Clear existing tabs first
    ORGA_Tabs = {}
    
    -- Create debug panel if it doesn't exist
    if not debugPanel then
        debugPanel = CreateDebugPanel()
    end
    
    if ORGA_PlayerInGuild then
        -- Player is in guild, initialize normal tabs
        print("|cff9966CC[ORGA]|r Guild member detected. Loading full addon functionality.")
        InitializeTabs()
    else
        -- Player is not in guild, create guest UI
        print("|cff9966CC[ORGA]|r Not in Only Rejects guild. Loading limited functionality.")
        CreateGuestTab()
    end
    
    -- Check for module loading (after some delay to allow for module registration)
    C_Timer.After(3, function()
        print("|cff9966CC[ORGA]|r Checking final module status:")
        print("|cff9966CC[ORGA]|r Tabs loaded: " .. #ORGA_Tabs)
        for i, tab in ipairs(ORGA_Tabs) do
            print("|cff9966CC[ORGA]|r   - " .. tab.name)
        end
        
        -- Re-run InitializeTabs to make sure all registered tabs are displayed
        InitializeTabs()
    end)
end

-- Register events for guild status changes
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE") -- Add this event for guild status changes
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Request guild roster (Classic API)
        GuildRoster()
        
        -- The guild info might not be immediately available at login
        -- Try multiple times with increasing delays
        local attempts = 0
        local maxAttempts = 5
        
        local function tryInitialize()
            attempts = attempts + 1
            GuildRoster() -- Request roster update
            
            -- Check if guild info is available
            local guildName = GetGuildInfo("player")
            if guildName or attempts >= maxAttempts then
                -- Either we have guild info, or we've tried enough times
                print("|cff9966CC[ORGA]|r Guild info check attempt " .. attempts .. ": " .. (guildName or "not available"))
                InitializeAddon()
            else
                -- Try again with increasing delay
                C_Timer.After(attempts * 0.5, tryInitialize)
            end
        end
        
        -- Start trying to initialize after a short delay
        C_Timer.After(0.5, tryInitialize)
    elseif event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
        -- Check if guild status changed
        local wasInGuild = ORGA_PlayerInGuild
        ORGA_PlayerInGuild = IsInOnlyRejectsGuild()
        
        -- If guild status changed, reinitialize UI
        if wasInGuild ~= ORGA_PlayerInGuild then
            -- Reload UI with appropriate tabs
            if ORGA_PlayerInGuild then
                print("|cff9966CC[ORGA]|r You are now in the Only Rejects guild. Addon functionality enabled.")
                ORGA_Tabs = {}
                C_Timer.After(0.5, InitializeTabs)
            else
                print("|cff9966CC[ORGA]|r You are no longer in the Only Rejects guild. Limited functionality available.")
                C_Timer.After(0.5, CreateGuestTab)
            end
        end
    end
end)

-- Delay initialization to ensure all tabs are registered
-- No longer needed as we now use InitializeAddon() with proper guild checks

------------------------------------------------
-- Minimap Button Implementation
------------------------------------------------

-- Create a namespace for helper functions
local MinimapButton = {}

-- Function to calculate minimap button position
function MinimapButton:CalculatePosition(angle)
    local radians = angle * math.pi / 180
    local radius = 80 -- Distance from minimap center
    local x = radius * math.cos(radians)
    local y = radius * math.sin(radians)
    return x, y
end

-- Function to handle minimap button dragging
function MinimapButton:OnDragStart(button)
    button:StartMoving()
    button:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        px, py = px / scale, py / scale
        
        local angle = math.deg(math.atan2(py - my, px - mx))
        if angle < 0 then angle = angle + 360 end
        
        -- Save the position for future sessions
        ORGA_WindowSettings.minimapPos = angle
        
        -- Update position of the minimap button
        local x, y = self:CalculatePosition(angle)
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end)
end

-- Function to handle minimap button drag stop
function MinimapButton:OnDragStop(button)
    button:StopMovingOrSizing()
    button:SetScript("OnUpdate", nil)
end

-- Function to toggle the main ORGA window
function MinimapButton:ToggleORGA()
    if ORGA:IsShown() then ORGA:Hide() else ORGA:Show() end
end

-- Initialize the minimap button
function MinimapButton:Initialize()
    -- Create a simple button without using templates that cause errors
    local button = CreateFrame("Button", "ORGAMinimapButton", Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetSize(31, 31)
    button:SetFrameLevel(8)
    
    -- Create a background
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetWidth(25)
    background:SetHeight(25)
    background:SetPoint("CENTER", 0, 0)
    
    -- Create the icon using ORGA's background texture
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(17)
    icon:SetHeight(17)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\AddOns\\ORGA\\Textures\\background.tga")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    -- Add an overlay icon
    local overlay = button:CreateTexture(nil, "ARTWORK", nil, 1)
    overlay:SetWidth(13)
    overlay:SetHeight(13)
    overlay:SetPoint("CENTER", 0, 0)
    overlay:SetTexture("Interface\\GuildFrame\\GuildLogo-NoLogo")
    overlay:SetVertexColor(0.8, 0.4, 1)
    
    -- Add a border texture
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(53)
    border:SetHeight(53)
    border:SetPoint("TOPLEFT", 0, 0)
    
    -- Set up highlights
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    -- Enable dragging of the button around the minimap
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)
    button:SetClampedToScreen(true)
    
    -- Set button scripts
    button:SetScript("OnDragStart", function() self:OnDragStart(button) end)
    button:SetScript("OnDragStop", function() self:OnDragStop(button) end)
    button:SetScript("OnClick", function() self:ToggleORGA() end)
    
    -- Add tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Only Rejects Guild Addon v" .. ORGA_VERSION_STRING)
        GameTooltip:AddLine("Left-Click: Toggle ORGA window", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move this button", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Position the button based on saved position
    local angle = ORGA_WindowSettings.minimapPos or 45
    local x, y = self:CalculatePosition(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    
    -- Store reference to button
    self.button = button
    
    -- Make sure the button stays on the minimap when it's scaled or shaped differently (e.g., square minimap addons)
    button:SetScript("OnUpdate", function()
        -- Only update occasionally to save performance
        if not self.lastUpdate or (GetTime() - self.lastUpdate > 1) then
            local angle = ORGA_WindowSettings.minimapPos or 45 -- Ensure we have a default value
            local x, y = self:CalculatePosition(angle)
            button:ClearAllPoints()
            button:SetPoint("CENTER", Minimap, "CENTER", x, y)
            self.lastUpdate = GetTime()
        end
    end)
end

-- Add a toggle command for the minimap button
SLASH_ORGABUTTON1 = "/orgabutton"
SlashCmdList["ORGABUTTON"] = function(msg)
    if msg == "hide" then
        if MinimapButton.button then
            MinimapButton.button:Hide()
            print("|cff9966CC[ORGA]|r Minimap button hidden. Type /orgabutton show to restore.")
        end
    elseif msg == "show" then
        if MinimapButton.button then
            MinimapButton.button:Show()
            print("|cff9966CC[ORGA]|r Minimap button shown.")
        end
    else
        print("|cff9966CC[ORGA]|r Minimap button commands:")
        print("  /orgabutton show - Show minimap button")
        print("  /orgabutton hide - Hide minimap button")
    end
end

-- Initialize the minimap button when addon loads
MinimapButton:Initialize()

-- Slash Commands
SLASH_ORGA1 = "/orga"
SlashCmdList["ORGA"] = function()
    MinimapButton:ToggleORGA()
end

-- Add help command
SLASH_ORGAHELP1 = "/orgahelp"
SlashCmdList["ORGAHELP"] = function()
    print("|cff9966CC=========== ORGA Commands ===========|r")
    print("|cff9966CC[ORGA v" .. ORGA_VERSION_STRING .. "]|r")
    print("|cff9966CC/orga|r - Toggle the main addon window")
    print("|cff9966CC/orgabutton show|r - Show minimap button")
    print("|cff9966CC/orgabutton hide|r - Hide minimap button")
    print("|cff9966CC/orgadebug|r - Show debug information window")
    print("|cff9966CC/orgaversion|r - Show addon version info")
    print("|cff9966CC/orgahelp|r - Show this help message")
    if ORGA_PlayerInGuild == true then
        print("|cff9966CC/orgasave|r - Manually save inventory data (ORGS module)")
        print("|cff9966CC/orgsverbose|r - Toggle verbose logging (ORGS module)")
    end
    print("|cff9966CC=======================================|r")
end

-- Add version command
SLASH_ORGAVERSION1 = "/orgaversion"
SlashCmdList["ORGAVERSION"] = function()
    print("|cff9966CC[ORGA]|r Version " .. ORGA_VERSION_STRING .. " (build " .. ORGA_VERSION.build .. ")")
end
