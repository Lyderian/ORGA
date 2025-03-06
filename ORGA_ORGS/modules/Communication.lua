-- ORGA_ORGS Communication Module
-- Handles addon communication for inventory synchronization

local COMM_PREFIX = "ORGA_ORGS"
local COMM_COMMANDS = {
    SYNC_REQUEST = "SYNC_REQ",
    SYNC_DATA = "SYNC_DATA",
    ITEM_REQUEST = "ITEM_REQ",
    ITEM_REQUEST_APPROVE = "ITEM_REQ_APP",
    ITEM_REQUEST_DENY = "ITEM_REQ_DENY"
}

-- Local variables
local isInitialized = false
local pendingData = {}
local lastSync = 0

-- Function to initialize communication
local function InitComm()
    if isInitialized then return end
    
    -- Register our communication prefix
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
        ORGS_DebugPrint("|cFFFFFFFF[ORGA_ORGS]|r Registered addon message prefix: " .. COMM_PREFIX)
        isInitialized = true
    else
        print("|cFFFFFFFF[ORGA_ORGS]|r ERROR: Could not register addon message prefix")
    end
end

-- Function to request inventory data from guild
local function RequestInventorySync()
    if not IsInGuild() then
        ORGS_DebugPrint("Not requesting sync - not in a guild")
        return
    end
    
    -- Send sync request to guild
    if isInitialized and C_ChatInfo then
        C_ChatInfo.SendAddonMessage(COMM_PREFIX, COMM_COMMANDS.SYNC_REQUEST, "GUILD")
        ORGS_DebugPrint("Sent inventory sync request to guild")
    else
        ORGS_DebugPrint("Cannot send sync request - communication not initialized")
    end
end

-- Helper function to chunk data for sending
local function ChunkData(data, maxSize)
    maxSize = maxSize or 240 -- Allow for overhead
    local chunks = {}
    local totalLen = #data
    local numChunks = math.ceil(totalLen / maxSize)
    
    for i = 1, numChunks do
        local startPos = (i-1) * maxSize + 1
        local endPos = math.min(startPos + maxSize - 1, totalLen)
        table.insert(chunks, string.sub(data, startPos, endPos))
    end
    
    return chunks, numChunks
end

-- Function to send inventory data response
local function SendInventoryData(targetChannel)
    if not isInitialized then
        ORGS_DebugPrint("Cannot send inventory data - communication not initialized")
        return
    end
    
    if not C_ChatInfo then
        ORGS_DebugPrint("Cannot send inventory data - C_ChatInfo not available")
        return
    end
    
    targetChannel = targetChannel or "GUILD"
    
    -- Skip if not in guild and trying to send to guild
    if targetChannel == "GUILD" and not IsInGuild() then
        ORGS_DebugPrint("Not sending inventory data - not in a guild")
        return
    end
    
    local playerName = UnitName("player")
    
    -- Check if we have data to send
    if not ORGA_Data or not ORGA_Data[playerName] or not ORGA_Data[playerName].inventory then
        ORGS_DebugPrint("No inventory data to send")
        return
    end
    
    -- Serialize inventory data
    local serializedData = {}
    serializedData.player = playerName
    serializedData.timestamp = time()
    serializedData.gold = GetMoney()
    serializedData.items = {}
    
    -- Only include key inventory data to reduce message size
    for itemID, itemData in pairs(ORGA_Data[playerName].inventory) do
        serializedData.items[itemID] = {
            count = itemData.count,
            name = itemData.name,
            quality = itemData.quality
        }
    end
    
    -- Convert table to string (basic serialization)
    local dataString = ORGS_SerializeTable(serializedData)
    
    -- Split data into chunks if needed
    local chunks, numChunks = ChunkData(dataString)
    
    -- Send header message with chunk count
    local headerMsg = COMM_COMMANDS.SYNC_DATA .. "|" .. numChunks .. "|" .. playerName
    C_ChatInfo.SendAddonMessage(COMM_PREFIX, headerMsg, targetChannel)
    
    -- Send each chunk
    for i, chunk in ipairs(chunks) do
        local msg = COMM_COMMANDS.SYNC_DATA .. "|" .. i .. "|" .. chunk
        C_ChatInfo.SendAddonMessage(COMM_PREFIX, msg, targetChannel)
    end
    
    ORGS_DebugPrint("Sent inventory data to " .. targetChannel .. " (" .. #chunks .. " chunks)")
end

-- Function to send an item request to guild
local function SendItemRequest(itemID, count, message)
    if not isInitialized then
        print("|cFFFFFFFF[ORGA_ORGS]|r Cannot send item request - communication not initialized")
        return false
    end
    
    if not C_ChatInfo then
        print("|cFFFFFFFF[ORGA_ORGS]|r Cannot send item request - C_ChatInfo not available")
        return false
    end
    
    if not IsInGuild() then
        print("|cFFFFFFFF[ORGA_ORGS]|r Cannot send item request - not in a guild")
        return false
    end
    
    -- Format request data
    local playerName = UnitName("player")
    local timestamp = time()
    
    -- Create a request ID
    local requestID = playerName .. "-" .. itemID .. "-" .. timestamp
    
    -- Format message
    message = message or ""
    local reqMsg = COMM_COMMANDS.ITEM_REQUEST .. "|" .. requestID .. "|" .. itemID .. "|" .. count .. "|" .. message
    
    -- Send request to guild
    C_ChatInfo.SendAddonMessage(COMM_PREFIX, reqMsg, "GUILD")
    
    -- Store request locally
    if not ORGS_RequestedItems[playerName] then
        ORGS_RequestedItems[playerName] = {}
    end
    
    ORGS_RequestedItems[playerName][requestID] = {
        itemID = itemID,
        count = count,
        timestamp = timestamp,
        status = "pending"
    }
    
    print("|cFFFFFFFF[ORGA_ORGS]|r Item request sent to guild bank alts")
    return true
end

-- Function to respond to an item request
local function RespondToItemRequest(requestID, approve, responder)
    if not isInitialized then
        print("|cFFFFFFFF[ORGA_ORGS]|r Cannot respond to item request - communication not initialized")
        return false
    end
    
    if not C_ChatInfo then
        print("|cFFFFFFFF[ORGA_ORGS]|r Cannot respond to item request - C_ChatInfo not available")
        return false
    end
    
    if not IsInGuild() then
        print("|cFFFFFFFF[ORGA_ORGS]|r Cannot respond to item request - not in a guild")
        return false
    end
    
    -- Extract requester from request ID
    local requester = string.match(requestID, "([^-]+)%-")
    if not requester then
        print("|cFFFFFFFF[ORGA_ORGS]|r Invalid request ID format")
        return false
    end
    
    -- Format response command
    local command = approve and COMM_COMMANDS.ITEM_REQUEST_APPROVE or COMM_COMMANDS.ITEM_REQUEST_DENY
    
    -- Format response message
    local respMsg = command .. "|" .. requestID .. "|" .. responder
    
    -- Send whisper to requester
    C_ChatInfo.SendAddonMessage(COMM_PREFIX, respMsg, "WHISPER", requester)
    
    print("|cFFFFFFFF[ORGA_ORGS]|r Item request " .. (approve and "approved" or "denied") .. " and sent to " .. requester)
    return true
end

-- Process incoming messages
local function ProcessSyncRequest(sender)
    ORGS_DebugPrint("Received sync request from " .. sender)
    
    -- Only bank alts respond to sync requests
    local playerName = UnitName("player")
    if ORGS_BankAlts and ORGS_BankAlts[playerName] then
        -- Add a small delay to avoid message collision
        C_Timer.After(math.random(1, 3), function()
            SendInventoryData("GUILD")
        end)
    end
end

local function ProcessSyncData(message, sender)
    -- Parse the header: SYNC_DATA|chunkCount|playerName or SYNC_DATA|chunkNum|chunkData
    local parts = {strsplit("|", message, 3)}
    
    if #parts < 3 then
        ORGS_DebugPrint("Invalid sync data format from " .. sender)
        return
    end
    
    local chunkInfo = tonumber(parts[2])
    local data = parts[3]
    
    -- If chunkInfo is not a number, something is wrong
    if not chunkInfo then
        ORGS_DebugPrint("Invalid chunk info in sync data from " .. sender)
        return
    end
    
    -- If this is a header message (chunkInfo = total number of chunks)
    if not pendingData[sender] or not pendingData[sender].receivingData then
        -- Initialize pending data for this sender
        pendingData[sender] = {
            totalChunks = chunkInfo,
            receivedChunks = 0,
            data = {},
            receivingData = true,
            senderName = data -- In header, data is the player name
        }
        ORGS_DebugPrint("Initiated sync from " .. sender .. " with " .. chunkInfo .. " chunks for player " .. data)
        return
    end
    
    -- Otherwise this is a data chunk, with chunkInfo being the chunk number
    local chunkNum = chunkInfo
    
    -- Store this chunk
    pendingData[sender].data[chunkNum] = data
    pendingData[sender].receivedChunks = pendingData[sender].receivedChunks + 1
    
    -- If we've received all chunks, process the complete data
    if pendingData[sender].receivedChunks >= pendingData[sender].totalChunks then
        -- Combine all chunks
        local completeData = ""
        for i = 1, pendingData[sender].totalChunks do
            completeData = completeData .. (pendingData[sender].data[i] or "")
        end
        
        -- Deserialize the data
        local success, inventoryData = pcall(ORGS_DeserializeTable, completeData)
        
        if success and inventoryData then
            -- Process the inventory data
            ProcessInventoryUpdate(inventoryData, pendingData[sender].senderName)
        else
            ORGS_DebugPrint("Failed to deserialize inventory data from " .. sender)
        end
        
        -- Clear pending data
        pendingData[sender] = nil
        ORGS_DebugPrint("Completed sync from " .. sender)
    end
end

-- Process inventory updates from other players
local function ProcessInventoryUpdate(data, playerName)
    if not data or not playerName then
        ORGS_DebugPrint("Invalid inventory update data")
        return
    end
    
    -- Store in ORGA_Data
    if not ORGA_Data then ORGA_Data = {} end
    if not ORGA_Data[playerName] then ORGA_Data[playerName] = {} end
    
    -- Update gold
    ORGA_Data[playerName].gold = data.gold
    
    -- Update inventory
    ORGA_Data[playerName].inventory = data.items
    
    -- Update timestamp
    ORGA_Data[playerName].lastUpdate = data.timestamp
    
    -- Mark as bank alt if appropriate
    if ORGS_BankAlts and ORGS_BankAlts[playerName] then
        ORGA_Data[playerName].isORGSBankAlt = true
    end
    
    ORGS_DebugPrint("Updated inventory data for " .. playerName)
    
    -- Refresh UI if visible
    ORGS_RefreshInventoryDisplay()
end

-- Process item requests as a bank alt
local function ProcessItemRequest(message, sender)
    local parts = {strsplit("|", message, 5)}
    if #parts < 4 then
        ORGS_DebugPrint("Invalid item request format from " .. sender)
        return
    end
    
    local requestID = parts[2]
    local itemID = tonumber(parts[3])
    local count = tonumber(parts[4])
    local requestMsg = parts[5] or ""
    
    if not requestID or not itemID or not count then
        ORGS_DebugPrint("Invalid item request data from " .. sender)
        return
    end
    
    -- Only process if we're a bank alt
    local playerName = UnitName("player")
    if not ORGS_BankAlts or not ORGS_BankAlts[playerName] then
        return
    end
    
    -- Store the request for handling in the UI
    if not ORGS_RequestedItems[sender] then
        ORGS_RequestedItems[sender] = {}
    end
    
    ORGS_RequestedItems[sender][requestID] = {
        itemID = itemID,
        count = count,
        timestamp = time(),
        status = "pending",
        message = requestMsg
    }
    
    -- Notify the bank alt
    print("|cFFFFFFFF[ORGA_ORGS]|r " .. sender .. " has requested " .. count .. "x [" .. 
          (GetItemInfo(itemID) or "Item:" .. itemID) .. "]")
    
    -- Refresh the requests UI if it's visible
    ORGS_RefreshRequestsUI()
}

-- Process response to item request as a requester
local function ProcessItemRequestResponse(message, sender, isApproved)
    local parts = {strsplit("|", message, 3)}
    if #parts < 3 then
        ORGS_DebugPrint("Invalid item request response format from " .. sender)
        return
    end
    
    local requestID = parts[2]
    local responder = parts[3]
    
    -- Extract requester from request ID
    local requester = string.match(requestID, "([^-]+)%-")
    if not requester then
        ORGS_DebugPrint("Invalid request ID format in response")
        return
    end
    
    local playerName = UnitName("player")
    if requester ~= playerName then
        -- This response isn't for us
        return
    end
    
    -- Update the request status
    if ORGS_RequestedItems and ORGS_RequestedItems[playerName] and ORGS_RequestedItems[playerName][requestID] then
        ORGS_RequestedItems[playerName][requestID].status = isApproved and "approved" or "denied"
        ORGS_RequestedItems[playerName][requestID].responder = responder
        ORGS_RequestedItems[playerName][requestID].responseTime = time()
        
        -- Get item name for display
        local itemID = ORGS_RequestedItems[playerName][requestID].itemID
        local itemName = GetItemInfo(itemID) or "Item:" .. itemID
        local count = ORGS_RequestedItems[playerName][requestID].count
        
        -- Notify the requester
        if isApproved then
            print("|cFF00FF00[ORGA_ORGS]|r Your request for " .. count .. "x [" .. itemName .. 
                  "] has been approved by " .. responder)
        else
            print("|cFFFF0000[ORGA_ORGS]|r Your request for " .. count .. "x [" .. itemName ..
                  "] has been denied by " .. responder)
        end
        
        -- Refresh cart UI if visible
        ORGS_RefreshCartDisplay()
    end
}

-- Create communication event handler
local commFrame = CreateFrame("Frame")
commFrame:RegisterEvent("CHAT_MSG_ADDON")
commFrame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    -- Filter out our own messages and validate prefix
    if prefix ~= COMM_PREFIX or sender == UnitName("player") then 
        return 
    end
    
    -- Remove realm part from sender name
    sender = strsplit("-", sender, 2)
    
    ORGS_DebugPrint("Received addon message from " .. sender .. " via " .. channel .. ": " .. message)
    
    -- Parse the command from the message
    local command = strsplit("|", message, 2)
    
    if command == COMM_COMMANDS.SYNC_REQUEST then
        ProcessSyncRequest(sender)
    elseif command == COMM_COMMANDS.SYNC_DATA then
        local remainder = select(2, strsplit("|", message, 2))
        ProcessSyncData(remainder, sender)
    elseif command == COMM_COMMANDS.ITEM_REQUEST then
        local remainder = select(2, strsplit("|", message, 2))
        ProcessItemRequest(remainder, sender)
    elseif command == COMM_COMMANDS.ITEM_REQUEST_APPROVE then
        local remainder = select(2, strsplit("|", message, 2))
        ProcessItemRequestResponse(remainder, sender, true)
    elseif command == COMM_COMMANDS.ITEM_REQUEST_DENY then
        local remainder = select(2, strsplit("|", message, 2))
        ProcessItemRequestResponse(remainder, sender, false)
    end
end)

-- Basic serialization functions for tables
function ORGS_SerializeTable(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false
    depth = depth or 0
    
    local tmp = string.rep(" ", depth)
    
    if name then
        tmp = tmp .. name .. " = "
    end
    
    if type(val) == "table" then
        tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")
        
        for k, v in pairs(val) do
            tmp =  tmp .. ORGS_SerializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
        end
        
        tmp = tmp .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
        tmp = tmp .. (val and "true" or "false")
    else
        tmp = tmp .. "\"[" .. type(val) .. "]\""
    end
    
    return tmp
end

function ORGS_DeserializeTable(str)
    local fn = loadstring("return " .. str)
    if fn then
        return fn()
    else
        return nil
    end
end

-- Public API
local ORGS_Comm = {
    InitComm = InitComm,
    RequestInventorySync = RequestInventorySync,
    SendInventoryData = SendInventoryData,
    SendItemRequest = SendItemRequest,
    RespondToItemRequest = RespondToItemRequest
}

-- Initialize on load
C_Timer.After(1, InitComm)

-- Return the module
return ORGS_Comm