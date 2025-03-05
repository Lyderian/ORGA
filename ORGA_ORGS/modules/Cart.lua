-- ORGA_ORGS Cart.lua - Shopping cart functionality

-- Function to handle item request
function ORGS_RequestItems()
    local playerName = UnitName("player")
    
    -- Initialize global variable if it doesn't exist
    if not ORGS_RequestedItems then
        ORGS_RequestedItems = {}
    end
    
    -- Create or update the player's request
    if not ORGS_RequestedItems[playerName] then
        ORGS_RequestedItems[playerName] = {}
    end
    
    -- Set request properties
    ORGS_RequestedItems[playerName].status = "Pending"
    ORGS_RequestedItems[playerName].requestTime = time()
    
    -- Ensure items table exists
    if not ORGS_RequestedItems[playerName].items then
        ORGS_RequestedItems[playerName].items = {}
    end
    
    -- Add items from cart to request
    local itemsRequested = 0
    for itemID, count in pairs(ORGS_Cart or {}) do
        -- Make sure we store a consistent type (for the request display)
        ORGS_RequestedItems[playerName].items[tostring(itemID)] = count
        itemsRequested = itemsRequested + 1
    end
    
    -- Only proceed if there are items in the cart
    if itemsRequested > 0 then
        print("|cff00ff00[ORGA_ORGS]: Request submitted with " .. itemsRequested .. " items! Bank alts have been notified.|r")
        
        -- Clear the cart after requesting
        ORGS_Cart = {}
    else
        print("|cffff0000[ORGA_ORGS]: No items in cart to request!|r")
    end
end