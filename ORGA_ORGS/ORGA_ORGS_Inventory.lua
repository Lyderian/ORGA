-- ORGA_ORGS_Inventory.lua - Inventory scanning and loading functions

-- Check if bank is open using multiple detection methods
function ORGS_IsBankOpen()
    -- Check for default Blizzard bank frame
    if BankFrame and BankFrame:IsShown() then
        return true
    end
    
    -- Check for different versions of Bagon/Bagnon
    -- Check standard Bagnon
    if _G["BagnonFramebank"] and _G["BagnonFramebank"]:IsShown() then
        return true
    end
    
    -- Check for other common Bagnon frame names
    if _G["BagnonBank"] and _G["BagnonBank"]:IsShown() then
        return true
    end
    
    -- Check for specific container IDs being shown
    -- This works with Bagnon and potentially other bag addons
    if _G["ContainerFrame6"] and _G["ContainerFrame6"]:IsShown() then
        return true
    end
    
    -- More generic approach - check if a relevant bank bag is accessible via API
    if C_Container then
        local bankBagSlots = C_Container.GetContainerNumSlots(BANK_CONTAINER)
        if bankBagSlots and bankBagSlots > 0 then
            return true
        end
    end
    
    -- As a last resort, try to get actual bank container slots
    -- If we can get slots for bank bags, the bank must be open
    for bag = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
        local slots = C_Container.GetContainerNumSlots(bag)
        if slots and slots > 0 then
            return true
        end
    end
    
    return false
end

-- Save player's inventory data
function ORGS_SaveInventoryData()
    local playerName = UnitName("player")
    
    if not ORGA_Data then
        ORGA_Data = {}
    end

    local isBankAlt = ORGS_BankAlts[playerName] or false
    ORGA_Data[playerName] = { inventory = {}, gold = GetMoney(), isORGSBankAlt = isBankAlt }
    local inventory = ORGA_Data[playerName].inventory

    ORGS_DebugPrint("|cff00ff00[ORGA_ORGS]: Saving data for " .. playerName .. "|r")

    -- First, let's just scan all inventory for bags directly
    print("|cff00ff00[ORGA_ORGS]: Scanning for bags in all inventory|r") -- Always show this message

    -- Add bag slots to be scanned - first backpack (0)
    local bagsToScan = {BACKPACK_CONTAINER}
    
    -- Add player bags (1-4)
    for i = 1, NUM_BAG_SLOTS do
        table.insert(bagsToScan, i)
    end
    
    -- First we'll scan all player bags for bag items
    for _, bagIndex in ipairs(bagsToScan) do
        local numSlots = C_Container.GetContainerNumSlots(bagIndex)
        print("|cff00ff00[ORGA_ORGS]: Scanning bag " .. bagIndex .. " with " .. numSlots .. " slots|r")
        
        for slot = 1, numSlots do
            local itemLink = C_Container.GetContainerItemLink(bagIndex, slot)
            if itemLink then
                local _, _, itemID = string.find(itemLink, "item:(%d+)")
                if itemID then
                    -- Check if this item is a bag by looking at its name/link
                    local itemInfo = C_Container.GetContainerItemInfo(bagIndex, slot)
                    if itemInfo and itemInfo.hyperlink then
                        local itemName = GetItemInfo(itemID)
                        
                        -- Check if it's a bag directly by item ID (more reliable than names)
                        if itemID == "4238" or itemID == 4238 then
                            -- Linen Bag
                            inventory["4238"] = (inventory["4238"] or 0) + 1
                            ORGS_DebugPrint("|cff00ff00[ORGA_ORGS]: Added Linen Bag to inventory (ID: 4238)|r")
                        elseif itemID == "4240" or itemID == 4240 then
                            -- Wool Bag
                            inventory["4240"] = (inventory["4240"] or 0) + 1
                            ORGS_DebugPrint("|cff00ff00[ORGA_ORGS]: Added Wool Bag to inventory (ID: 4240)|r")
                        elseif itemID == "4241" or itemID == 4241 then
                            -- Silk Bag
                            inventory["4241"] = (inventory["4241"] or 0) + 1
                            ORGS_DebugPrint("|cff00ff00[ORGA_ORGS]: Added Silk Bag to inventory (ID: 4241)|r")
                        elseif itemID == "10050" or itemID == 10050 then
                            -- Mageweave Bag
                            inventory["10050"] = (inventory["10050"] or 0) + 1
                            ORGS_DebugPrint("|cff00ff00[ORGA_ORGS]: Added Mageweave Bag to inventory (ID: 10050)|r")
                        elseif itemID == "14046" or itemID == 14046 then
                            -- Runecloth Bag
                            inventory["14046"] = (inventory["14046"] or 0) + 1
                            ORGS_DebugPrint("|cff00ff00[ORGA_ORGS]: Added Runecloth Bag to inventory (ID: 14046)|r")
                        elseif itemName and string.find(itemName:lower(), "bag") then
                            -- Some other type of bag
                            inventory[tostring(itemID)] = (inventory[tostring(itemID)] or 0) + 1
                            ORGS_DebugPrint("|cff00ff00[ORGA_ORGS]: Added bag item: " .. itemName .. " (ID: " .. itemID .. ")|r")
                        end
                    end
                end
            end
        end
    end

    -- Scan Main Inventory and Bags (now include everything, including bags inside bags)
    ORGS_ScanPlayerBags(inventory)

    -- Scan Bank Inventory (only if bank is open)
    if ORGS_IsBankOpen() then
        ORGS_ScanBankInventory(inventory)
    else
        ORGS_DebugPrint("|cff00ff00[ORGA_ORGS]: Bank is closed, skipping bank scan|r")
    end
    
    ORGS_DebugPrint("|cff00ff00[ORGA_ORGS]: Stored Gold: " .. ORGA_Data[playerName].gold .. " copper.|r")
end

-- Function to scan player bags
function ORGS_ScanPlayerBags(inventory)
    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemLink = C_Container.GetContainerItemLink(bag, slot)
            if itemLink then
                local _, _, itemID = string.find(itemLink, "item:(%d+)")
                if itemID then
                    local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                    local stackCount = itemInfo and itemInfo.stackCount or 1
                    -- Include all items in inventory, including bags
                    inventory[itemID] = (inventory[itemID] or 0) + stackCount
                    ORGS_DebugPrint("|cff00ff00[ORGA_ORGS]: Stored Bag Item: " .. itemID .. " x" .. inventory[itemID] .. "|r")
                end
            end
        end
    end
end

-- Function to scan bank inventory
function ORGS_ScanBankInventory(inventory)
    ORGS_DebugPrint("|cff00ff00[ORGA_ORGS]: Bank is open, scanning bank slots|r")
    
    -- For bank, we need to scan all the bank bag slots themselves
    print("|cff00ff00[ORGA_ORGS]: Scanning bank bag containers themselves|r") -- Always show this message
    
    if BANK_CONTAINER and C_Container.GetContainerNumSlots(BANK_CONTAINER) > 0 then
        -- Now scan the bank bag slots (normally 5-11 in Classic)
        for bagIndex = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
            local numSlots = C_Container.GetContainerNumSlots(bagIndex)
            print("|cff00ff00[ORGA_ORGS]: Bank bag " .. bagIndex .. " has " .. numSlots .. " slots|r") -- Always show
            
            -- If bag has slots, it's a bag - try to determine its type based on slot count
            if numSlots > 0 then
                -- Use slot count to make educated guesses about bag type
                if numSlots == 6 then
                    -- Likely a Linen Bag (6 slots)
                    inventory["4238"] = (inventory["4238"] or 0) + 1
                    print("|cff00ff00[ORGA_ORGS]: Detected Linen Bag (6 slots) at bank slot|r") -- Always show
                elseif numSlots == 8 then
                    -- Likely a Wool Bag (8 slots)
                    inventory["4240"] = (inventory["4240"] or 0) + 1
                    print("|cff00ff00[ORGA_ORGS]: Detected Wool Bag (8 slots) at bank slot|r") -- Always show
                elseif numSlots == 10 then
                    -- Likely a Silk Bag (10 slots)
                    inventory["4241"] = (inventory["4241"] or 0) + 1
                    print("|cff00ff00[ORGA_ORGS]: Detected Silk Bag (10 slots) at bank slot|r") -- Always show
                elseif numSlots == 12 then
                    -- Likely a Mageweave Bag (12 slots)
                    inventory["10050"] = (inventory["10050"] or 0) + 1  
                    print("|cff00ff00[ORGA_ORGS]: Detected Mageweave Bag (12 slots) at bank slot|r") -- Always show
                elseif numSlots == 14 then
                    -- Likely a Runecloth Bag (14 slots)
                    inventory["14046"] = (inventory["14046"] or 0) + 1
                    print("|cff00ff00[ORGA_ORGS]: Detected Runecloth Bag (14 slots) at bank slot|r") -- Always show
                elseif numSlots == 16 then
                    -- Likely a Traveler's Backpack or other 16-slot bag
                    inventory["4500"] = (inventory["4500"] or 0) + 1
                    print("|cff00ff00[ORGA_ORGS]: Detected Traveler's Backpack (16 slots) at bank slot|r") -- Always show
                elseif numSlots > 0 then
                    -- Some other bag type
                    print("|cffff9900[ORGA_ORGS]: Unknown bag type with " .. numSlots .. " slots|r") -- Always show
                end
            end
        end
    else
        print("|cffff0000[ORGA_ORGS]: Can't access bank container slots|r") -- Always show
    end
    
    -- Now scan the primary bank (slot -1 in Classic)
    local bankBagID = BANK_CONTAINER -- Normally -1
    print("|cff00ff00[ORGA_ORGS]: Scanning primary bank container|r") -- Always show this message
    
    -- Get the number of slots in the bank container
    local bankSlots = C_Container.GetContainerNumSlots(bankBagID)
    print("|cff00ff00[ORGA_ORGS]: Primary bank has " .. bankSlots .. " slots|r") -- Always show this message
    
    for slot = 1, bankSlots do
        local itemLink = C_Container.GetContainerItemLink(bankBagID, slot)
        if itemLink then
            local _, _, itemID = string.find(itemLink, "item:(%d+)")
            if itemID then
                local itemInfo = C_Container.GetContainerItemInfo(bankBagID, slot)
                local stackCount = itemInfo and itemInfo.stackCount or 1
                -- We want to include everything, including bags, in the inventory
                inventory[itemID] = (inventory[itemID] or 0) + stackCount
                print("|cff00ff00[ORGA_ORGS]: Stored Primary Bank Item: " .. itemID .. " x" .. stackCount .. "|r") -- Always show
            end
        end
    end
    
    -- Then scan bank bags (normally slots 5-11 in Classic)
    print("|cff00ff00[ORGA_ORGS]: Scanning bank bags|r") -- Always show this message
    for bag = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
        local bagSlots = C_Container.GetContainerNumSlots(bag)
        print("|cff00ff00[ORGA_ORGS]: Bank bag " .. bag .. " has " .. bagSlots .. " slots|r") -- Always show
        
        for slot = 1, bagSlots do
            local itemLink = C_Container.GetContainerItemLink(bag, slot)
            if itemLink then
                local _, _, itemID = string.find(itemLink, "item:(%d+)")
                if itemID then
                    local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                    local stackCount = itemInfo and itemInfo.stackCount or 1
                    -- We want to include everything, including bags, in the inventory
                    inventory[itemID] = (inventory[itemID] or 0) + stackCount
                    print("|cff00ff00[ORGA_ORGS]: Stored Bank Bag Item: " .. itemID .. " x" .. stackCount .. "|r") -- Always show
                end
            end
        end
    end
end

-- Function to add a standalone save button to the bank window
function ORGS_AddSaveButtonToBankFrame()
    -- Check if the button already exists
    if _G["ORGA_ORGSSaveButton"] then
        return
    end
    
    -- Determine which bank frame to use
    local bankParentFrame = BankFrame
    
    -- Check for Bagon
    if _G["BagnonFramebank"] and _G["BagnonFramebank"]:IsShown() then
        bankParentFrame = _G["BagnonFramebank"]
    end
    
    local saveButton = CreateFrame("Button", "ORGA_ORGSSaveButton", bankParentFrame, "UIPanelButtonTemplate")
    saveButton:SetSize(140, 25)
    saveButton:SetPoint("TOPRIGHT", bankParentFrame, "TOPRIGHT", -10, -30)
    saveButton:SetText("Scan ORGS Bank")
    saveButton:SetScript("OnClick", function()
        ORGS_SaveInventoryData()
        print("|cff00ff00[ORGA_ORGS]: Bank inventory scanned successfully!|r")
    end)
    saveButton:Show()
end

-- Load inventory data from all bank alts
function ORGS_LoadInventoryData()
    ORGS_Inventory = {}
    local totalGold = 0
    local bankAltGold = {}

    if ORGA_Data then
        ORGS_DebugPrint("|cff00ff00[ORGA_ORGS]: ORGA_Data detected. Loading latest snapshot...|r")
        for charName, data in pairs(ORGA_Data) do
            ORGS_DebugPrint("|cff00ff00[ORGA_ORGS]: Processing character: " .. charName .. "|r")
            
            -- Only load inventory from bank alts
            if data.isORGSBankAlt and data.inventory then
                for item, count in pairs(data.inventory) do
                    -- Combine quantities from all bank alts
                    ORGS_Inventory[item] = (ORGS_Inventory[item] or 0) + count
                    ORGS_DebugPrint("|cff00ff00[ORGA_ORGS]: Set item " .. item .. " x" .. ORGS_Inventory[item] .. "|r")
                end
                
                -- Track gold for each bank alt
                if data.gold then
                    totalGold = totalGold + data.gold
                    bankAltGold[charName] = data.gold
                end
            end
        end
    else
        print("|cffff0000[ORGA_ORGS]: ORGA_Data is nil. Inventory cannot be loaded.|r")
    end
    
    -- Store gold information
    ORGS_Inventory["Total Gold"] = totalGold
    ORGS_Inventory["Bank Alt Gold"] = bankAltGold
    
    ORGS_DebugPrint("|cff00ff00[ORGA_ORGS]: ORGS Inventory Loaded Successfully. Total Gold: " .. totalGold .. "|r")
    
    -- Initialize requested items table if it doesn't exist
    if not ORGS_RequestedItems then
        ORGS_RequestedItems = {}
    end
end