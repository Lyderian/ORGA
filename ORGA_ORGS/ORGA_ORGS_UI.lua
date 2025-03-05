-- ORGA_ORGS_UI.lua - User Interface functions

-- Function to show the ORGS inventory in the main frame
function ORGS_ShowInventoryUI(frame, suppressMessages)
    ORGS_LoadInventoryData()
    if not suppressMessages then
        print("|cff00ff00[ORGA_ORGS]: Displaying ORGS Inventory|r")
    end

    -- Clear the frame
    for _, child in ipairs({frame:GetChildren()}) do
        child:Hide()
    end
    
    -- Create a dark background frame for the entire content
    local mainBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    mainBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
    mainBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 85) -- Leave room for bottom panel
    mainBg:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    mainBg:SetBackdropColor(0.1, 0.1, 0.1, 0.9) -- Very dark, nearly black, high opacity
    
    -- Add close button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    closeButton:SetScript("OnClick", function()
        if frame:GetParent() then
            frame:GetParent():Hide()
        end
    end)
    
    -- Create a frame for the fixed header section (non-scrollable)
    local headerFrame = CreateFrame("Frame", nil, mainBg)
    headerFrame:SetPoint("TOPLEFT", mainBg, "TOPLEFT", 8, -8)
    headerFrame:SetPoint("TOPRIGHT", mainBg, "TOPRIGHT", -8, -8)
    headerFrame:SetHeight(170) -- Fixed height for gold info section
    
    -- Title for the inventory section
    local inventoryTitle = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    inventoryTitle:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 10, -10)
    inventoryTitle:SetText("ORGS Bank Inventory")
    
    -- Create header and gold display
    ORGS_CreateGoldDisplay(headerFrame)
    
    -- Create a scrollframe for ONLY the items section that adapts to parent size
    local scrollFrame = CreateFrame("ScrollFrame", nil, mainBg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", mainBg, "BOTTOMRIGHT", -28, 8)
    
    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetWidth(scrollFrame:GetWidth() - 15) -- Account for scroll bar
    contentFrame:SetHeight(800) -- Will be adjusted based on content
    scrollFrame:SetScrollChild(contentFrame)
    
    -- Update content width when parent frame changes size
    scrollFrame:HookScript("OnSizeChanged", function(self)
        contentFrame:SetWidth(self:GetWidth() - 15)
    end)
    
    -- Create item grid
    ORGS_CreateItemGrid(contentFrame, frame)
    
    -- Create a bottom panel for cart and requests
    ORGS_CreateBottomPanel(frame)
    
    ORGS_DebugPrint("|cff00ff00[ORGA_ORGS]: Inventory Display Updated|r")
end

-- Function to create the gold display section
function ORGS_CreateGoldDisplay(headerFrame)
    local goldY = -40
    local bankAltGold = ORGS_Inventory["Bank Alt Gold"] or {}
    
    local goldHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    goldHeader:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 10, goldY)
    goldHeader:SetText("Guild Bank Gold")
    goldY = goldY - 25
    
    -- Create a gold display frame with 2-column layout
    local goldFrame = CreateFrame("Frame", nil, headerFrame)
    goldFrame:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 20, goldY)
    goldFrame:SetPoint("TOPRIGHT", headerFrame, "TOPRIGHT", -20, goldY)
    goldFrame:SetHeight(70) -- Enough for multiple bank alts
    
    -- Sort bank alt names for consistent display
    local sortedNames = {}
    for charName in pairs(bankAltGold) do
        table.insert(sortedNames, charName)
    end
    table.sort(sortedNames)
    
    -- Layout banks in two columns
    local colWidth = (goldFrame:GetWidth() / 2) - 20
    local row, col = 0, 0
    for i, charName in ipairs(sortedNames) do
        local goldAmount = bankAltGold[charName]
        local altGoldText = goldFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        altGoldText:SetWidth(colWidth)
        altGoldText:SetPoint("TOPLEFT", goldFrame, "TOPLEFT", col * (colWidth + 40), -row * 20)
        altGoldText:SetText(charName .. ": " .. ORGS_FormatGold(goldAmount))
        
        -- Alternate columns, new row when both columns filled
        col = col + 1
        if col >= 2 then
            col = 0
            row = row + 1
        end
    end
    
    -- Total gold display
    goldY = -110
    local totalGoldText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    totalGoldText:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 10, goldY)
    totalGoldText:SetText("Total Gold: " .. ORGS_FormatGold(ORGS_Inventory["Total Gold"] or 0))
    
    -- Add a separator line
    goldY = goldY - 20
    local separator = headerFrame:CreateTexture(nil, "ARTWORK")
    separator:SetHeight(2)
    separator:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 10, goldY)
    separator:SetPoint("TOPRIGHT", headerFrame, "TOPRIGHT", -10, goldY)
    separator:SetColorTexture(0.6, 0.6, 0.6, 0.8)
    
    -- Add an "Available Items" header at the bottom of the header section
    goldY = goldY - 20
    local itemsHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    itemsHeader:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 10, goldY)
    itemsHeader:SetText("Available Items")
end

-- Function to create the item grid 
function ORGS_CreateItemGrid(contentFrame, parentFrame)
    -- Items will start at the top of the content frame
    local itemsStartY = -10
    local itemIndex = 0
    local itemsPerRow = 8
    
    -- Get and sort item IDs (excluding special keys)
    local itemsList = {}
    for itemID, count in pairs(ORGS_Inventory) do
        if type(itemID) == "number" or (type(itemID) == "string" and itemID:match("^%d+$")) then
            -- Convert string item IDs to numbers
            local numericID = tonumber(itemID)
            if numericID then
                table.insert(itemsList, numericID)
            end
        end
    end
    
    -- Get count before display - debug info 
    ORGS_DebugPrint("|cff00ff00[ORGA_ORGS]: Found " .. #itemsList .. " items to display|r")
    
    -- Sort items alphabetically by name when possible
    table.sort(itemsList, function(a, b)
        local nameA = GetItemInfo(a)
        local nameB = GetItemInfo(b)
        if nameA and nameB then
            return nameA < nameB
        elseif nameA then
            return true
        elseif nameB then
            return false
        else
            return a < b -- Fallback to numeric sort
        end
    end)
    
    -- Debug the inventory data
    for itemID, count in pairs(ORGS_Inventory) do
        if type(itemID) == "number" or (type(itemID) == "string" and itemID:match("^%d+$")) then
            ORGS_DebugPrint("|cff00ff00[ORGA_ORGS Debug]: Item " .. itemID .. " count: " .. (count or "nil") .. "|r")
        end
    end
    
    -- Calculate number of items per row based on frame width
    -- This makes the grid responsive to window size
    local frameWidth = contentFrame:GetWidth()
    local itemButtonSize = 36 -- Item button size
    local itemSpacing = 8 -- Space between items
    local effectiveItemWidth = itemButtonSize + itemSpacing
    local leftMargin = 10
    local rightMargin = 15
    local availableWidth = frameWidth - leftMargin - rightMargin
    
    -- Make sure we always display at least 6 items per row
    local calculatedItemsPerRow = math.max(6, math.floor(availableWidth / effectiveItemWidth))
    itemsPerRow = calculatedItemsPerRow
    
    -- Add resize handler to recalculate grid when window size changes
    contentFrame:HookScript("OnSizeChanged", function()
        -- Only update if we already have items displayed
        if itemIndex > 0 then
            ORGS_ShowInventoryUI(parentFrame, true) -- Pass true to suppress messages
        end
    end)
    
    -- Create items grid
    for _, itemID in ipairs(itemsList) do
        -- Make sure we store and access with consistent types (always numeric)
        local itemCount = ORGS_Inventory[itemID] or ORGS_Inventory[tostring(itemID)] or 0
        ORGS_DebugPrint("|cff00ff00[ORGA_ORGS]: Displaying item " .. itemID .. " with count " .. itemCount .. "|r")
        
        local itemButton = CreateFrame("Button", nil, contentFrame, "ItemButtonTemplate")
        itemButton:SetSize(itemButtonSize, itemButtonSize)
        
        -- Calculate position using dynamic items per row
        local column = itemIndex % itemsPerRow
        local row = math.floor(itemIndex / itemsPerRow)
        
        -- Space evenly across available width
        local horizontalSpacing = availableWidth / itemsPerRow
        local xPos = leftMargin + (column * horizontalSpacing) + (horizontalSpacing - itemButtonSize) / 2
        local yPos = itemsStartY - (row * 50) - 20
        
        itemButton:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", xPos, yPos)

        -- Item tooltip
        itemButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. itemID)
            GameTooltip:Show()
        end)
        itemButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        -- Add to cart on click
        itemButton:SetScript("OnClick", function(self)
            if not ORGS_Cart then ORGS_Cart = {} end
            
            -- Get current count which should never be nil
            local currentCount = itemCount
            
            if IsShiftKeyDown() and ORGS_Cart[itemID] then
                -- Remove from cart when shift-clicking
                ORGS_Cart[itemID] = nil
                print("|cff00ff00[ORGA_ORGS]: Removed item from cart.|r")
            else
                -- Add to cart (or increment if already there)
                local requestAmount = IsControlKeyDown() and currentCount or 1
                local newAmount = (ORGS_Cart[itemID] or 0) + requestAmount
                
                -- Cap at available amount
                if currentCount > 0 and newAmount > currentCount then
                    newAmount = currentCount
                end
                
                ORGS_Cart[itemID] = newAmount
                
                -- Get item name safely
                local itemName = GetItemInfo(itemID) or ("Item #" .. itemID)
                print("|cff00ff00[ORGA_ORGS]: Added to cart: " .. itemName .. " x" .. requestAmount .. "|r") -- Always show this message
            end
            
            -- Update cart display
            ORGS_ShowInventoryUI(parentFrame)
        end)

        -- Set item texture
        local itemTexture = select(10, GetItemInfo(itemID))
        if itemTexture then
            itemButton.icon:SetTexture(itemTexture)
        else
            print("|cffff0000[ORGA_ORGS]: Warning: GetItemInfo returned nil for item " .. itemID .. "|r")
        end

        -- Show item count with a more visible style
        local countText = itemButton:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        countText:SetPoint("BOTTOMRIGHT", itemButton, "BOTTOMRIGHT", -2, 2)
        countText:SetText(itemCount) -- Use the correct itemCount variable
        
        -- Create a small backdrop for the count to make it more readable
        local countBg = itemButton:CreateTexture(nil, "BACKGROUND")
        countBg:SetPoint("BOTTOMRIGHT", itemButton, "BOTTOMRIGHT", 0, 0)
        countBg:SetSize(18, 14)
        countBg:SetColorTexture(0, 0, 0, 0.7)
        
        -- If item is in cart, add a cart indicator
        if ORGS_Cart and ORGS_Cart[itemID] then
            local cartIndicator = itemButton:CreateTexture(nil, "OVERLAY")
            cartIndicator:SetSize(16, 16)
            cartIndicator:SetPoint("TOPRIGHT", itemButton, "TOPRIGHT", 0, 0)
            cartIndicator:SetTexture("Interface\\GroupFrame\\UI-Group-MasterLooter")
            
            local cartCount = itemButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            cartCount:SetPoint("TOPLEFT", itemButton, "TOPLEFT", 2, -2)
            cartCount:SetTextColor(0, 1, 0)
            cartCount:SetText(ORGS_Cart[itemID])
        end

        itemButton:Show()
        itemIndex = itemIndex + 1
    end
    
    -- Adjust content frame height based on item count
    local totalRows = math.ceil(itemIndex / itemsPerRow)
    -- Add more space for each row and extra padding at the bottom
    local contentHeight = math.max(800, itemsStartY - (totalRows * 50) - 100)
    contentFrame:SetHeight(contentHeight)
end

-- Function to create the bottom panel with cart information
function ORGS_CreateBottomPanel(frame)
    -- Create a bottom panel for cart and requests that adapts to parent width
    local bottomPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    bottomPanel:SetHeight(80)
    bottomPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 5, 5)
    bottomPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
    bottomPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 12,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    
    -- Add shopping cart summary to the panel
    local cartTitle = bottomPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cartTitle:SetPoint("TOPLEFT", bottomPanel, "TOPLEFT", 15, -10)
    cartTitle:SetText("Shopping Cart")
    
    -- Create Request button in the panel
    local requestButton = CreateFrame("Button", nil, bottomPanel, "UIPanelButtonTemplate")
    requestButton:SetSize(120, 25)
    requestButton:SetPoint("TOPRIGHT", bottomPanel, "TOPRIGHT", -15, -10)
    requestButton:SetText("Request Items")
    requestButton:SetScript("OnClick", ORGS_RequestItems)
    
    -- Cart count summary
    local cartCount = 0
    local itemCount = 0
    for _, count in pairs(ORGS_Cart or {}) do
        cartCount = cartCount + 1
        itemCount = itemCount + count
    end
    
    local cartSummary = bottomPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cartSummary:SetPoint("TOPLEFT", cartTitle, "BOTTOMLEFT", 0, -5)
    cartSummary:SetText(cartCount .. " unique items (" .. itemCount .. " total)")
    
    -- Show instructions
    local instructions = bottomPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("BOTTOM", bottomPanel, "BOTTOM", 0, 10)
    instructions:SetText("Click: Add 1 | Ctrl+Click: Add max | Shift+Click: Remove")
    
    -- Add Save Inventory button for bank alts (next to request button)
    local isBankAlt = ORGS_BankAlts[UnitName("player")] or false
    if isBankAlt then
        local saveButton = CreateFrame("Button", nil, bottomPanel, "UIPanelButtonTemplate")
        saveButton:SetSize(120, 25)
        saveButton:SetPoint("RIGHT", requestButton, "LEFT", -10, 0)
        saveButton:SetText("Scan Inventory")
        saveButton:SetScript("OnClick", ORGS_SaveInventoryData)
    end
end

-- Function to show pending requests (for bank alts)
function ORGS_ShowRequestsUI(frame)
    -- Clear the frame
    for _, child in ipairs({frame:GetChildren()}) do
        child:Hide()
    end
    
    -- Create title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -10)
    title:SetText("Pending ORGS Requests")
    
    -- Add close button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    closeButton:SetScript("OnClick", function()
        if frame:GetParent() then
            frame:GetParent():Hide()
        end
    end)
    
    -- Create a dark background frame to improve readability
    local darkBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    darkBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -25)
    darkBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 50) -- Space for buttons
    darkBg:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    darkBg:SetBackdropColor(0.1, 0.1, 0.1, 0.9) -- Very dark, nearly black, high opacity
    
    -- Create scrollframe for requests that adapts to parent size
    local scrollFrame = CreateFrame("ScrollFrame", nil, darkBg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", darkBg, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", darkBg, "BOTTOMRIGHT", -28, 8) -- Room for scroll bar
    
    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetWidth(scrollFrame:GetWidth() - 15) -- Account for scroll bar
    contentFrame:SetHeight(800) -- Will be adjusted based on content
    scrollFrame:SetScrollChild(contentFrame)
    
    -- Update content width when parent frame changes size
    scrollFrame:HookScript("OnSizeChanged", function(self)
        contentFrame:SetWidth(self:GetWidth() - 15)
    end)
    
    -- Check if there are any pending requests
    local hasPendingRequests = false
    local yOffset = 0
    
    -- Debug requests info
    ORGS_DebugPrint("|cff00ff00[ORGA_ORGS Requests]: Checking for pending requests...|r")
    if ORGS_RequestedItems then
        for requester, requestData in pairs(ORGS_RequestedItems) do
            ORGS_DebugPrint("|cff00ff00[ORGA_ORGS Requests]: Found request from " .. requester .. ", status: " .. (requestData.status or "nil") .. "|r")
            if requestData.items then
                local itemCount = 0
                for _, _ in pairs(requestData.items) do
                    itemCount = itemCount + 1
                end
                ORGS_DebugPrint("|cff00ff00[ORGA_ORGS Requests]: Request contains " .. itemCount .. " items|r")
            else
                ORGS_DebugPrint("|cffff0000[ORGA_ORGS Requests]: Request contains no items table|r")
            end
            
            if requestData and requestData.status == "Pending" then
                hasPendingRequests = true
                
                -- Create requester header
                local requesterText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                requesterText:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, -yOffset - 10)
                requesterText:SetText("Request from: " .. requester)
                yOffset = yOffset + 30
                
                -- Create time text
                local timeAgo = SecondsToTime(time() - (requestData.requestTime or 0))
                local timeText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                timeText:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, -yOffset)
                timeText:SetText("Requested: " .. timeAgo .. " ago")
                yOffset = yOffset + 20
                
                -- List requested items
                local itemsText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                itemsText:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, -yOffset)
                itemsText:SetText("Requested Items:")
                yOffset = yOffset + 20
                
                -- Display items in a grid
                local itemIndex = 0
                for itemID, count in pairs(requestData.items or {}) do
                    -- Debug the item ID
                    ORGS_DebugPrint("|cff00ff00[ORGA_ORGS Requests]: Processing request item: " .. itemID .. " x" .. count .. "|r")
                    
                    -- Ensure the itemID is numeric for item functions
                    local numericID = tonumber(itemID)
                    if not numericID then
                        ORGS_DebugPrint("|cffff0000[ORGA_ORGS Requests]: Warning - non-numeric item ID: " .. itemID .. "|r")
                    else
                        -- Create item button with proper icon and count
                        local itemButton = CreateFrame("Button", nil, contentFrame, "ItemButtonTemplate")
                        itemButton:SetSize(36, 36)
                        local xPos = 10 + (itemIndex % 8) * 45
                        local rowYOffset = math.floor(itemIndex / 8) * 50 -- Increased spacing
                        itemButton:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", xPos, -yOffset - rowYOffset)
                        
                        -- Set tooltip
                        itemButton:SetScript("OnEnter", function(self)
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetHyperlink("item:" .. numericID)
                            GameTooltip:Show()
                        end)
                        itemButton:SetScript("OnLeave", function()
                            GameTooltip:Hide()
                        end)
                        
                        -- Try to get item info with safety checks
                        local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(numericID)
                        
                        -- Set item texture
                        if itemTexture then
                            itemButton.icon:SetTexture(itemTexture)
                            ORGS_DebugPrint("|cff00ff00[ORGA_ORGS Requests]: Set texture for item " .. (itemName or numericID) .. "|r")
                        else
                            ORGS_DebugPrint("|cffff0000[ORGA_ORGS Requests]: Warning - no texture for item " .. numericID .. "|r")
                            -- Set a default texture
                            itemButton.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                        end
                        
                        -- Show item count with improved visibility
                        local countText = itemButton:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                        countText:SetPoint("BOTTOMRIGHT", itemButton, "BOTTOMRIGHT", -2, 2)
                        countText:SetText(count)
                        
                        -- Create a small backdrop for the count to make it more readable
                        local countBg = itemButton:CreateTexture(nil, "BACKGROUND")
                        countBg:SetPoint("BOTTOMRIGHT", itemButton, "BOTTOMRIGHT", 0, 0)
                        countBg:SetSize(18, 14)
                        countBg:SetColorTexture(0, 0, 0, 0.7)
                        
                        itemIndex = itemIndex + 1
                    end
                end
                
                -- Adjust for item grid height
                yOffset = yOffset + (math.ceil(itemIndex / 8) * 45) + 10
                
                -- Add Complete and Reject buttons
                local completeButton = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
                completeButton:SetSize(100, 25)
                completeButton:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, -yOffset - 10)
                completeButton:SetText("Complete")
                completeButton:SetScript("OnClick", function()
                    ORGS_RequestedItems[requester].status = "Completed"
                    ORGS_RequestedItems[requester].completedTime = time()
                    ORGS_RequestedItems[requester].completedBy = UnitName("player")
                    print("|cff00ff00[ORGA_ORGS]: Marked request from " .. requester .. " as completed.|r")
                    ORGS_ShowRequestsUI(frame)
                end)
                
                local rejectButton = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
                rejectButton:SetSize(100, 25)
                rejectButton:SetPoint("LEFT", completeButton, "RIGHT", 10, 0)
                rejectButton:SetText("Reject")
                rejectButton:SetScript("OnClick", function()
                    ORGS_RequestedItems[requester].status = "Rejected"
                    ORGS_RequestedItems[requester].rejectedTime = time()
                    ORGS_RequestedItems[requester].rejectedBy = UnitName("player")
                    print("|cffff0000[ORGA_ORGS]: Marked request from " .. requester .. " as rejected.|r")
                    ORGS_ShowRequestsUI(frame)
                end)
                
                yOffset = yOffset + 50 -- Space for the next request section
            end
        end
    end
    
    if not hasPendingRequests then
        local noRequestsText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noRequestsText:SetPoint("CENTER", contentFrame, "CENTER", 0, 0)
        noRequestsText:SetText("No pending requests")
    end
    
    -- Adjust content frame height
    contentFrame:SetHeight(math.max(400, yOffset + 50))
    
    -- Add back button
    local backButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    backButton:SetSize(100, 25)
    backButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
    backButton:SetText("Back to Inventory")
    backButton:SetScript("OnClick", function()
        ORGS_ShowInventoryUI(frame)
    end)
end