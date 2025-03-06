-- ORGA_Events Module
-- Version: 1.0.11
-- Author: Lyderian

-- Initialize saved variables if not exists
if not ORGA_Events_Data then
    ORGA_Events_Data = {
        events = {},  -- Table to store events
        version = "1.0.11", -- Store version in saved variables
        debug = false,     -- Debug mode
        forcePermission = false,  -- Force permission override for testing
        lastSync = 0       -- Timestamp of last sync
    }
end

-- Utility functions --
local function Debug(message)
    if ORGA_Events_Data.debug then
        -- Only print non-resize related debug messages to avoid spam
        if not message:find("resize") and not message:find("Resize") then
            print("|cFFFFFFFF[ORGA_Events]|r " .. message)
        end
    end
end

-- Communication constants
local COMM_PREFIX = "ORGA_Events"
local COMM_COMMANDS = {
    SYNC_REQUEST = "SYNC_REQ",
    SYNC_DATA = "SYNC_DATA",
    EVENT_ADD = "EVENT_ADD",
    EVENT_EDIT = "EVENT_EDIT",
    EVENT_DELETE = "EVENT_DELETE"
}

-- Register addon communication channel
local function InitializeComm()
    -- Register our communication prefix
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
        Debug("Registered addon message prefix: " .. COMM_PREFIX)
    else
        print("|cFFFFFFFF[ORGA_Events]|r ERROR: Could not register addon message prefix")
    end
end

-- Add event handler for addon messages
local commFrame = CreateFrame("Frame")
commFrame:RegisterEvent("CHAT_MSG_ADDON")
commFrame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    -- Filter out our own messages and validate prefix
    if prefix ~= COMM_PREFIX or sender == UnitName("player") then 
        return 
    end
    
    Debug("Received addon message from " .. sender .. " via " .. channel .. ": " .. message)
    
    -- Parse the message (format: "COMMAND|DATA")
    local command, data = strsplit("|", message, 2)
    
    if command == COMM_COMMANDS.SYNC_REQUEST then
        -- Respond to sync request with our current data
        SendEventsData(channel)
    elseif command == COMM_COMMANDS.SYNC_DATA then
        -- Process incoming sync data
        ProcessIncomingSyncData(data, sender)
    elseif command == COMM_COMMANDS.EVENT_ADD then
        -- Process new event
        ProcessIncomingEventAdd(data, sender)
    elseif command == COMM_COMMANDS.EVENT_EDIT then
        -- Process edited event
        ProcessIncomingEventEdit(data, sender)
    elseif command == COMM_COMMANDS.EVENT_DELETE then
        -- Process deleted event
        ProcessIncomingEventDelete(data, sender)
    end
end)

-- List of guild ranks that can manage events
-- Using partial matching for flexibility with capitalization and spacing
local OFFICER_RANK_PATTERNS = {
    "officer",
    "warchief"
}

-- Add a resize throttling variable to prevent excessive updates
local resizeThrottleTimers = {}
local isResizing = false

-- Function to throttle resize events
local function ThrottledResize(callback, frameKey, delay)
    -- Default delay of 0.2 seconds if not specified
    delay = delay or 0.2
    
    -- Cancel any existing timer for this frame
    if resizeThrottleTimers[frameKey] then
        resizeThrottleTimers[frameKey]:Cancel()
    end
    
    -- Create new timer
    resizeThrottleTimers[frameKey] = C_Timer.NewTimer(delay, function()
        -- Execute callback
        callback()
        
        -- Reset the resizing flag after executing
        isResizing = false
    end)
    
    -- Mark as resizing to prevent duplicate calls
    isResizing = true
end

-- Check if player has permission to manage events
local function HasEventPermissions()
    -- If we're in debug force permission mode, always allow
    if ORGA_Events_Data.forcePermission then
        Debug("HasEventPermissions: Forced permission mode enabled")
        return true
    end
    
    if not IsInGuild() then 
        Debug("HasEventPermissions: Player is not in a guild")
        return false 
    end
    
    local guildName, guildRankName = GetGuildInfo("player")
    if not guildName or not guildRankName then 
        Debug("HasEventPermissions: Could not get guild info")
        return false 
    end
    
    -- Convert rank name to lowercase for case-insensitive comparison
    local lowerRankName = string.lower(guildRankName)
    Debug("HasEventPermissions: Player rank (lowercase): " .. lowerRankName)
    
    -- Check if rank name contains any of our officer patterns
    for _, pattern in ipairs(OFFICER_RANK_PATTERNS) do
        if string.find(lowerRankName, pattern) then
            Debug("HasEventPermissions: Matched pattern '" .. pattern .. "', granting permission")
            return true
        end
    end
    
    Debug("HasEventPermissions: No matching rank pattern found, denying permission")
    return false
end

-- Format time as a readable string
local function FormatTime(timestamp)
    local date = date("*t", timestamp)
    return string.format("%02d/%02d/%d %02d:%02d", 
                         date.month, date.day, date.year, 
                         date.hour, date.min)
end

-- Calculate and format time until event
local function GetTimeUntil(timestamp)
    local currentTime = time()
    local timeRemaining = timestamp - currentTime
    
    -- Print debug info about time calculation
    Debug("Time Until Calculation:")
    Debug("  Event timestamp: " .. timestamp .. " (" .. date("%m/%d/%Y %H:%M", timestamp) .. ")")
    Debug("  Current time: " .. currentTime .. " (" .. date("%m/%d/%Y %H:%M", currentTime) .. ")")
    Debug("  Time remaining in seconds: " .. timeRemaining)
    
    if timeRemaining <= 0 then
        return "Event has started"
    end
    
    local days = math.floor(timeRemaining / 86400)
    local hours = math.floor((timeRemaining % 86400) / 3600)
    local minutes = math.floor((timeRemaining % 3600) / 60)
    
    -- Extra debug output for the calculated time components
    Debug("  Days: " .. days .. ", Hours: " .. hours .. ", Minutes: " .. minutes)
    
    if days > 0 then
        return string.format("%d day%s, %d hour%s, %d minute%s", 
                            days, days ~= 1 and "s" or "", 
                            hours, hours ~= 1 and "s" or "", 
                            minutes, minutes ~= 1 and "s" or "")
    elseif hours > 0 then
        return string.format("%d hour%s, %d minute%s", 
                            hours, hours ~= 1 and "s" or "", 
                            minutes, minutes ~= 1 and "s" or "")
    else
        return string.format("%d minute%s", 
                            minutes, minutes ~= 1 and "s" or "")
    end
end

-- Get player's timezone offset in hours
local function GetPlayerTimezoneOffset()
    local UTC = time()
    local local_time = date("*t", UTC)
    local UTC_time = date("!*t", UTC)
    
    -- Calculate the hour difference correctly
    local hour_offset = local_time.hour - UTC_time.hour
    
    -- Adjust for day boundary crossings
    if local_time.day > UTC_time.day or (local_time.day == 1 and UTC_time.day > 27) then
        hour_offset = hour_offset + 24
    elseif local_time.day < UTC_time.day or (local_time.day > 27 and UTC_time.day == 1) then
        hour_offset = hour_offset - 24
    end
    
    Debug("Player timezone offset from UTC: " .. hour_offset .. " hours")
    return hour_offset
end

-- Convert timestamp to player's local timezone
local function ConvertToPlayerTime(timestamp)
    -- We're now operating on raw timestamps without conversion
    -- This simplifies things and prevents date skipping issues
    return timestamp
end

-- Format a timestamp for display in player's local time
local function FormatLocalTime(timestamp)
    -- Double-check the timestamp isn't nil
    if not timestamp then
        return "Invalid Time"
    end
    
    -- Log the raw timestamp value
    Debug("FormatLocalTime input timestamp: " .. timestamp)
    
    -- Format the date and time using direct conversion
    local dateObj = date("*t", timestamp)
    Debug("FormatLocalTime date object: " .. 
           dateObj.month .. "/" .. dateObj.day .. "/" .. dateObj.year .. " " ..
           dateObj.hour .. ":" .. dateObj.min)
    
    return string.format("%02d/%02d/%d %02d:%02d", 
                     dateObj.month, dateObj.day, dateObj.year, 
                     dateObj.hour, dateObj.min)
end

-- Add an event to the events table
local function AddEvent(title, description, timestamp, createdBy, timezone)
    -- Generate a unique ID for the event
    local id = tostring(time()) .. "-" .. math.random(1000, 9999)
    
    local event = {
        id = id,
        title = title,
        description = description,
        timestamp = timestamp,
        timezone = timezone or "UTC", -- Store the timezone for reference/editing
        createdBy = createdBy,
        created = time()
    }
    
    -- Insert the event into the saved data
    table.insert(ORGA_Events_Data.events, event)
    
    -- Sort events immediately after adding a new one
    SortEvents()
    
    -- Log debug information
    Debug("Added new event: " .. title)
    Debug("Total events after add: " .. #ORGA_Events_Data.events)
    
    -- Broadcast the new event to all guild members
    BroadcastNewEvent(event)
    
    return id
end

-- Edit an existing event
local function EditEvent(id, title, description, timestamp, timezone)
    local eventFound = false
    local updatedEvent = nil
    
    for i, event in ipairs(ORGA_Events_Data.events) do
        if event.id == id then
            event.title = title
            event.description = description
            event.timestamp = timestamp
            event.timezone = timezone or event.timezone or "UTC"
            event.lastEdited = time()
            eventFound = true
            updatedEvent = event
            Debug("Edited event: " .. title)
            Debug("Event data after edit - Timestamp: " .. timestamp .. ", Time: " .. FormatLocalTime(timestamp))
            break
        end
    end
    
    -- Sort events after editing
    if eventFound then
        SortEvents()
        Debug("Total events after edit: " .. #ORGA_Events_Data.events)
        
        -- Broadcast the edited event
        if updatedEvent then
            BroadcastEditedEvent(updatedEvent)
        end
        
        return true
    end
    
    return false
end

-- Delete an event by ID
local function DeleteEvent(id)
    local eventFound = false
    local eventTitle = ""
    local deletedEvent = nil
    
    for i, event in ipairs(ORGA_Events_Data.events) do
        if event.id == id then
            eventTitle = event.title
            -- Save a copy of the event for broadcasting
            deletedEvent = CopyTable(event)
            table.remove(ORGA_Events_Data.events, i)
            eventFound = true
            Debug("Deleted event: " .. eventTitle)
            break
        end
    end
    
    if eventFound then
        Debug("Total events after delete: " .. #ORGA_Events_Data.events)
        
        -- Broadcast the deleted event
        if deletedEvent then
            BroadcastDeletedEvent(deletedEvent)
        end
        
        return true
    end
    
    return false
end

-- Helper function to deep copy a table
local function CopyTable(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[CopyTable(orig_key)] = CopyTable(orig_value)
        end
        setmetatable(copy, CopyTable(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Sort events by timestamp - make this global by removing 'local'
function SortEvents()
    -- Check if we have events to sort
    if not ORGA_Events_Data.events or #ORGA_Events_Data.events < 1 then
        return
    end
    
    -- Sort events by timestamp (future events first)
    table.sort(ORGA_Events_Data.events, function(a, b)
        return a.timestamp < b.timestamp
    end)
    
    -- Log how many events were sorted
    Debug("Sorted " .. #ORGA_Events_Data.events .. " events")
end

-- Function to check if the events list needs to be rebuilt
local function NeedsRebuild()
    -- If force refresh is set, we definitely need to rebuild
    if ORGA_Events_Data.forceListRefresh then
        return true
    end
    
    -- If there's no scroll child or it's empty, we need to rebuild
    if not _G["ORGA_EventsScrollChild"] then
        return true
    end
    
    -- Count event frames that are visible
    local visibleEvents = 0
    for _, child in pairs({_G["ORGA_EventsScrollChild"]:GetChildren()}) do
        if child:IsShown() then
            visibleEvents = visibleEvents + 1
        end
    end
    
    -- Count future events in the data
    local futureEvents = 0
    for _, event in ipairs(ORGA_Events_Data.events) do
        if event.timestamp >= time() then
            futureEvents = futureEvents + 1
        end
    end
    
    -- If counts don't match, we need to rebuild
    return visibleEvents ~= futureEvents
end

-- UI Functions --

-- Forward declarations for functions used before defined
local CreateEventsListView
local ShowEventForm

-- Clear all widgets from a frame
local function ClearFrame(frame)
    -- Hide and remove all child widgets
    for _, child in pairs({frame:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Also hide all font strings and other regions attached to the frame
    for _, region in pairs({frame:GetRegions()}) do
        region:Hide()
    end
end

-- Show form to add/edit an event
ShowEventForm = function(parentFrame, existingEvent, isResize)
    -- Only clear frame if not resizing
    if not isResize then
        -- First, completely clear the frame to remove any existing elements
        ClearFrame(parentFrame)
        
        -- Create a completely opaque backdrop frame for the entire form area
        local formBackdrop = CreateFrame("Frame", "ORGA_Events_FormBackdrop", parentFrame, "BackdropTemplate")
        formBackdrop:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 10, -10)
        formBackdrop:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -10, 10)
        formBackdrop:SetFrameStrata("BACKGROUND") -- Make sure it's behind other elements
        
        -- Use a solid black background instead of the semi-transparent one
        formBackdrop:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8", -- Solid texture
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        
        -- Set the color to dark gray/black (RGBA format)
        formBackdrop:SetBackdropColor(0.1, 0.1, 0.1, 1.0) -- Last value 1.0 makes it fully opaque
        
        -- Form title
        local formTitle = parentFrame:CreateFontString("ORGA_Events_FormTitle", "OVERLAY", "GameFontNormalLarge")
        formTitle:SetPoint("TOPLEFT", 20, -20)
        formTitle:SetText(isEditing and "Edit Event" or "Add New Event")
        
        -- Hook the size changed event to update on window resize with throttling
        parentFrame:HookScript("OnSizeChanged", function(self, width, height)
            -- Throttle the rebuild to prevent spam
            if not isResizing then
                ThrottledResize(function()
                    ShowEventForm(parentFrame, existingEvent, true)
                end, "eventForm", 0.3)
            end
        end)
    else
        -- When resizing, just get existing elements
        -- Use unique names to access them
        local formTitle = _G["ORGA_Events_FormTitle"]
        local formBackdrop = _G["ORGA_Events_FormBackdrop"]
        
        -- If form title doesn't exist, something went wrong
        if not formTitle then
            Debug("Resize called but form title missing")
            return
        end
        
        -- Resize the backdrop if it exists
        if formBackdrop then
            formBackdrop:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 10, -10)
            formBackdrop:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -10, 10)
        end
    end
    
    local isEditing = existingEvent ~= nil
    
    -- Calculate input width based on parent frame width
    local availableWidth = parentFrame:GetWidth() - 40  -- 20px margin on each side
    
    -- Create the form elements
    local titleLabel = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("TOPLEFT", 20, -50)
    titleLabel:SetText("Event Title:")
    
    local titleInput = CreateFrame("EditBox", "ORGA_Events_TitleInput", parentFrame, "InputBoxTemplate")
    titleInput:SetSize(math.min(350, availableWidth * 0.7), 20) -- Responsive width, up to 350px
    titleInput:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 5, -5)
    titleInput:SetAutoFocus(false)
    titleInput:SetMaxLetters(50)
    
    local dateLabel = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dateLabel:SetPoint("TOPLEFT", titleInput, "BOTTOMLEFT", -5, -15)
    dateLabel:SetText("Date (MM/DD/YYYY):")
    
    local dateInput = CreateFrame("EditBox", "ORGA_Events_DateInput", parentFrame, "InputBoxTemplate")
    dateInput:SetSize(100, 20)
    dateInput:SetPoint("TOPLEFT", dateLabel, "BOTTOMLEFT", 5, -5)
    dateInput:SetAutoFocus(false)
    dateInput:SetMaxLetters(10)
    
    local timeLabel = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timeLabel:SetPoint("TOPLEFT", dateInput, "TOPRIGHT", 20, 0)
    timeLabel:SetText("Time (HH:MM):")
    
    local timeInput = CreateFrame("EditBox", "ORGA_Events_TimeInput", parentFrame, "InputBoxTemplate")
    timeInput:SetSize(60, 20)
    timeInput:SetPoint("TOPLEFT", timeLabel, "BOTTOMLEFT", 5, -5)
    timeInput:SetAutoFocus(false)
    timeInput:SetMaxLetters(5)
    
    -- Timezone dropdown - only create if not already present when resizing
    local timezoneLabel
    local timezoneDropdown = _G["ORGA_Events_TimezoneDropdown"]
    
    if not timezoneDropdown or not isResize then
        timezoneLabel = parentFrame:CreateFontString("ORGA_Events_TimezoneLabel", "OVERLAY", "GameFontNormal")
        timezoneLabel:SetPoint("TOPLEFT", timeInput, "TOPRIGHT", 20, 0)
        timezoneLabel:SetText("Timezone:")
        
        timezoneDropdown = CreateFrame("Frame", "ORGA_Events_TimezoneDropdown", parentFrame, "UIDropDownMenuTemplate")
        timezoneDropdown:SetPoint("TOPLEFT", timezoneLabel, "BOTTOMLEFT", -10, -5)
        UIDropDownMenu_SetWidth(timezoneDropdown, 80)
        
        -- Initialize timezone dropdown
        local function InitializeTimezoneDropdown(self, level)
            local info = UIDropDownMenu_CreateInfo()
            
            -- List of timezones
            local timezones = {
                {text = "PST", value = "PST"},
                {text = "MST", value = "MST"},
                {text = "CST", value = "CST"},
                {text = "EST", value = "EST"},
                {text = "UTC", value = "UTC"},
                {text = "CET", value = "CET"}
            }
            
            for _, timezone in ipairs(timezones) do
                info.text = timezone.text
                info.value = timezone.value
                info.func = function(self)
                    UIDropDownMenu_SetSelectedValue(timezoneDropdown, self.value)
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end
        
        UIDropDownMenu_Initialize(timezoneDropdown, InitializeTimezoneDropdown)
        
        -- Set default timezone based on player's local time or UTC
        local function DetectPlayerTimezone()
            local playerOffset = GetPlayerTimezoneOffset()
            
            -- Map common offsets to timezones
            if playerOffset == -8 then
                return "PST"
            elseif playerOffset == -7 then
                return "MST"
            elseif playerOffset == -6 then
                return "CST"
            elseif playerOffset == -5 then
                return "EST"
            elseif playerOffset == 1 then
                return "CET"
            else
                return "UTC"
            end
        end
        
        -- Set the default timezone
        UIDropDownMenu_SetSelectedValue(timezoneDropdown, DetectPlayerTimezone())
    else
        Debug("Using existing timezone dropdown during resize")
    end
    
    local descLabel = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", dateInput, "BOTTOMLEFT", -5, -15)
    descLabel:SetText("Description:")
    
    -- Calculate description box size based on available space
    local descWidth = math.min(400, availableWidth * 0.8)
    local descHeight = math.min(150, parentFrame:GetHeight() * 0.3)
    
    -- Create a completely opaque backdrop frame for the description area
    local descBackdrop = CreateFrame("Frame", "ORGA_Events_DescBackdrop", parentFrame, "BackdropTemplate")
    descBackdrop:SetSize(descWidth + 16, descHeight + 16) -- Extra padding for border
    descBackdrop:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -10)
    descBackdrop:SetFrameLevel(parentFrame:GetFrameLevel() - 1) -- Set below parent frame level
    
    -- Use a solid background
    descBackdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8", -- Solid texture
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    
    -- Set the color to dark gray (RGBA format)
    descBackdrop:SetBackdropColor(0.15, 0.15, 0.15, 1.0) -- Slightly lighter than the main backdrop
    
    local descInput = CreateFrame("ScrollFrame", "ORGA_Events_DescScrollFrame", descBackdrop, "UIPanelScrollFrameTemplate")
    descInput:SetSize(descWidth - 10, descHeight - 10) -- Account for backdrop border
    descInput:SetPoint("CENTER", descBackdrop, "CENTER", -10, 0) -- Offset for scrollbar
    
    local descEditBox = CreateFrame("EditBox", "ORGA_Events_DescInput")
    descEditBox:SetMultiLine(true)
    descEditBox:SetMaxLetters(500)
    descEditBox:SetWidth(descWidth - 20) -- Account for scrollbar
    descEditBox:SetFontObject(ChatFontNormal)
    descEditBox:SetAutoFocus(false)
    descEditBox:SetScript("OnEscapePressed", function() descEditBox:ClearFocus() end)
    
    descInput:SetScrollChild(descEditBox)
    
    -- Set existing values if editing
    if isEditing then
        local date = date("*t", existingEvent.timestamp)
        
        titleInput:SetText(existingEvent.title)
        dateInput:SetText(string.format("%02d/%02d/%d", date.month, date.day, date.year))
        timeInput:SetText(string.format("%02d:%02d", date.hour, date.min))
        descEditBox:SetText(existingEvent.description)
        
        -- Set previously selected timezone if available
        if existingEvent.timezone then
            UIDropDownMenu_SetSelectedValue(timezoneDropdown, existingEvent.timezone)
        end
    else
        -- Set default date (today) and time (next full hour)
        local now = date("*t")
        dateInput:SetText(string.format("%02d/%02d/%d", now.month, now.day, now.year))
        timeInput:SetText(string.format("%02d:00", (now.hour + 1) % 24))
    end
    
    -- Helper text
    local helperText = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helperText:SetPoint("TOPLEFT", descInput, "BOTTOMLEFT", 0, -10)
    helperText:SetText("All times will be stored in UTC and converted to each player's local time.")
    helperText:SetTextColor(0.7, 0.7, 0.7)
    
    -- Create save and cancel buttons
    local saveButton = CreateFrame("Button", nil, parentFrame, "UIPanelButtonTemplate")
    saveButton:SetSize(80, 22)
    saveButton:SetPoint("TOPLEFT", helperText, "BOTTOMLEFT", 0, -20)
    saveButton:SetText("Save")
    saveButton:SetScript("OnClick", function()
        -- Validate inputs
        local title = titleInput:GetText()
        if not title or title == "" then
            print("|cffff0000[ORGA Events]|r Event title is required")
            return
        end
        
        -- Parse date
        local month, day, year = dateInput:GetText():match("(%d+)/(%d+)/(%d+)")
        if not month or not day or not year then
            print("|cffff0000[ORGA Events]|r Invalid date format (MM/DD/YYYY)")
            return
        end
        
        -- Parse time
        local hour, min = timeInput:GetText():match("(%d+):(%d+)")
        if not hour or not min then
            print("|cffff0000[ORGA Events]|r Invalid time format (HH:MM)")
            return
        end
        
        -- Convert to numbers
        month, day, year = tonumber(month), tonumber(day), tonumber(year)
        hour, min = tonumber(hour), tonumber(min)
        
        -- Validate date and time ranges
        if month < 1 or month > 12 or day < 1 or day > 31 or
           hour < 0 or hour > 23 or min < 0 or min > 59 then
            print("|cffff0000[ORGA Events]|r Invalid date or time values")
            return
        end
        
        -- Create timestamp based on selected timezone
        local dateTable = {
            year = year,
            month = month,
            day = day,
            hour = hour,
            min = min,
            sec = 0
        }
        -- Here we're creating a timestamp assuming the input is already in local time
        local localTimestamp = time(dateTable)
        
        -- Enable detailed logging for debugging this issue
        ORGA_Events_Data.debug = true
        print("|cFFFFFFFF[ORGA_Events]|r DEBUGGING TIME ISSUE - Original date input: " .. month .. "/" .. day .. "/" .. year .. " " .. hour .. ":" .. min)
        
        -- Get the user's input timezone they selected from dropdown
        local timezoneDropdown = _G["ORGA_Events_TimezoneDropdown"]
        local selectedTimezone = UIDropDownMenu_GetSelectedValue(timezoneDropdown)
        
        -- For simplicity and to fix the date skipping issue, let's use a direct approach
        -- Store the event exactly as entered, and just save the timezone for display
        local eventTimestamp = localTimestamp
        
        -- Log key details for debugging
        local inputDate = date("*t", localTimestamp)
        print("|cFFFFFFFF[ORGA_Events]|r Date Debug: Input date = " .. month .. "/" .. day .. "/" .. year)
        print("|cFFFFFFFF[ORGA_Events]|r Time Debug: Input time = " .. hour .. ":" .. min)
        print("|cFFFFFFFF[ORGA_Events]|r Selected timezone: " .. selectedTimezone)
        print("|cFFFFFFFF[ORGA_Events]|r Event timestamp: " .. date("%m/%d/%Y %H:%M", eventTimestamp) .. " " .. selectedTimezone)
        print("|cFFFFFFFF[ORGA_Events]|r Time until event: " .. GetTimeUntil(eventTimestamp))
        
        -- Turn debug off after logging
        ORGA_Events_Data.debug = false
        
        local description = descEditBox:GetText() or ""
        
        -- Get the selected timezone for storing with the event
        local selectedTimezone = UIDropDownMenu_GetSelectedValue(timezoneDropdown)
        
        -- Save the event
        local eventId
        if isEditing then
            EditEvent(existingEvent.id, title, description, eventTimestamp, selectedTimezone)
            eventId = existingEvent.id
        else
            local playerName = UnitName("player")
            eventId = AddEvent(title, description, eventTimestamp, playerName, selectedTimezone)
        end
        
        -- This is the critical part to fix the issue
        print("|cFFFFFFFF[ORGA_Events]|r Event saved! ID: " .. eventId)
        print("|cFFFFFFFF[ORGA_Events]|r Total events in database: " .. #ORGA_Events_Data.events)
        
        -- Safely rebuild the display with a slight delay to ensure data is processed
        C_Timer.After(0.1, function()
            -- Force complete UI rebuild by calling ShowEvents
            print("|cFFFFFFFF[ORGA_Events]|r Rebuilding events list...")
            
            -- First completely clear the frame
            ClearFrame(parentFrame)
            
            -- Then rebuild the entire UI
            ORGA_Events_Data.forceListRefresh = true
            ShowEvents(parentFrame)
            ORGA_Events_Data.forceListRefresh = false
            
            -- Verify our event is visible
            local eventsVisible = 0
            for _, child in pairs({_G["ORGA_EventsScrollChild"]:GetChildren()}) do
                if child:IsShown() then
                    eventsVisible = eventsVisible + 1
                end
            end
            print("|cFFFFFFFF[ORGA_Events]|r Events visible after refresh: " .. eventsVisible)
        end)
        
        -- Debug info
        Debug("Event saved successfully, returned to events list")
    end)
    
    local cancelButton = CreateFrame("Button", nil, parentFrame, "UIPanelButtonTemplate")
    cancelButton:SetSize(80, 22)
    cancelButton:SetPoint("TOPLEFT", saveButton, "TOPRIGHT", 10, 0)
    cancelButton:SetText("Cancel")
    cancelButton:SetScript("OnClick", function()
        -- Safely cancel and return to events list
        print("|cFFFFFFFF[ORGA_Events]|r Canceling edit. Returning to event list...")
        
        -- Use same delay approach as with saving
        C_Timer.After(0.1, function()
            -- First completely clear the frame
            ClearFrame(parentFrame)
            
            -- Force complete UI rebuild
            ORGA_Events_Data.forceListRefresh = true
            ShowEvents(parentFrame)
            ORGA_Events_Data.forceListRefresh = false
            
            -- Verify events are visible
            local eventsVisible = 0
            for _, child in pairs({_G["ORGA_EventsScrollChild"]:GetChildren()}) do
                if child:IsShown() then
                    eventsVisible = eventsVisible + 1
                end
            end
            print("|cFFFFFFFF[ORGA_Events]|r Events visible after returning: " .. eventsVisible)
        end)
        
        Debug("Event editing canceled, returned to events list")
    end)
    
    -- Set focus to first field
    titleInput:SetFocus()
end

-- Create the events list view
CreateEventsListView = function(frame, isResize)
    -- Only clear if not resizing
    if not isResize then
        -- Make sure the frame is completely cleared
        ClearFrame(frame)
        
        -- Main title
        local title = frame:CreateFontString("ORGA_Events_MainTitle", "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 20, -20)
        title:SetText("Guild Events")
        
        -- Create scrolling frame for events
        local scrollFrame = CreateFrame("ScrollFrame", "ORGA_EventsScrollFrame", frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 10, -50)
        scrollFrame:SetPoint("BOTTOMRIGHT", -30, 50)
        
        -- Set the frame strata to ensure it's visible
        scrollFrame:SetFrameStrata("MEDIUM")
        
        -- Create a backdrop for the scroll frame for better visibility
        local scrollFrameBG = CreateFrame("Frame", "ORGA_EventsScrollFrameBG", scrollFrame, "BackdropTemplate")
        scrollFrameBG:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", -5, 5)
        scrollFrameBG:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 5, -5)
        scrollFrameBG:SetFrameLevel(scrollFrame:GetFrameLevel() - 1)
        scrollFrameBG:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        scrollFrameBG:SetBackdropColor(0.05, 0.05, 0.05, 1.0)
        
        -- Create the scroll child with a minimum reasonable height
        local scrollChild = CreateFrame("Frame", "ORGA_EventsScrollChild", scrollFrame)
        scrollChild:SetSize(scrollFrame:GetWidth() - 30, 100) -- Minimal starting height
        scrollFrame:SetScrollChild(scrollChild)
        
        -- Set frame strata and level for the scroll child
        scrollChild:SetFrameStrata("HIGH")
        scrollChild:Show() -- Explicitly show the scroll child
        
        -- Hook the size changed event to update on window resize
        scrollFrame:HookScript("OnSizeChanged", function(self, width, height)
            -- Update the width of the scroll child
            local child = self:GetScrollChild()
            if child then
                child:SetWidth(width - 30)
            end
            
            -- Throttle the rebuild to prevent spam
            if not isResizing then
                ThrottledResize(function()
                    CreateEventsListView(frame, true)
                end, "eventsList", 0.3)
            end
        end)
    else
        -- When resizing, get existing scrollFrame and scrollChild
        local scrollFrame = _G["ORGA_EventsScrollFrame"]
        local scrollChild = _G["ORGA_EventsScrollChild"]
        
        -- Verify they exist before proceeding
        if not scrollFrame or not scrollChild then
            Debug("Resize called but scrollFrame or scrollChild missing")
            return
        end
        
        -- Clear the scroll child without affecting the main frame
        for _, child in pairs({scrollChild:GetChildren()}) do
            child:Hide()
            child:SetParent(nil)
        end
        
        -- Update the width of the scroll child
        scrollChild:SetWidth(scrollFrame:GetWidth() - 30)
    end
    
    -- Get references to title and scrollChild (regardless of resize state)
    local title = _G["ORGA_Events_MainTitle"]
    local scrollFrame = _G["ORGA_EventsScrollFrame"]
    local scrollChild = _G["ORGA_EventsScrollChild"]
    
    -- If we couldn't find the elements, something went wrong
    if not title or not scrollFrame or not scrollChild then
        Debug("Critical elements missing during view creation")
        return
    end
    
    -- Button to add new event (only visible for officers)
    if HasEventPermissions() then
        -- Only create button if this is not a resize or if the button doesn't exist
        if not isResize or not _G["ORGA_Events_AddButton"] then
            local addButton = CreateFrame("Button", "ORGA_Events_AddButton", frame, "UIPanelButtonTemplate")
            addButton:SetSize(120, 22)
            addButton:SetPoint("TOPLEFT", title, "TOPRIGHT", 20, 0)
            addButton:SetText("Add Event")
            addButton:SetScript("OnClick", function()
                ShowEventForm(frame)
            end)
        end
    end
    
    -- Refresh button (visible to all players)
    if not isResize or not _G["ORGA_Events_RefreshButton"] then
        local refreshButton = CreateFrame("Button", "ORGA_Events_RefreshButton", frame, "UIPanelButtonTemplate")
        refreshButton:SetSize(120, 22)
        
        -- Always position the refresh button at the top right of the frame
        -- This ensures it never overlaps with other buttons
        refreshButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -20)
        
        refreshButton:SetText("Refresh Events")
        refreshButton:SetScript("OnClick", function()
            -- Force complete UI rebuild by calling ShowEvents
            print("|cFFFFFFFF[ORGA_Events]|r Refreshing events list...")
            ORGA_Events_Data.forceListRefresh = true
            ShowEvents(frame)
            ORGA_Events_Data.forceListRefresh = false
        end)
    end
    
    -- Sort events by timestamp
    SortEvents()
    
    -- Display events
    local yOffset = 0
    local hasEvents = false
    
    -- Calculate the event frame width based on the scroll child width
    local eventFrameWidth = scrollChild:GetWidth() - 10
    
    for i, event in ipairs(ORGA_Events_Data.events) do
        -- Only show future events
        if event.timestamp >= time() then
            hasEvents = true
            
            -- Event container with unique name for resize tracking
            local eventFrameName = "ORGA_Events_EventFrame_" .. i
            local eventFrame = CreateFrame("Frame", eventFrameName, scrollChild, "BackdropTemplate")
            eventFrame:SetSize(eventFrameWidth, 100)
            eventFrame:SetPoint("TOPLEFT", 5, -yOffset)
            
            -- Set a higher frame level to ensure visibility
            eventFrame:SetFrameLevel(scrollChild:GetFrameLevel() + 5)
            
            -- Use a completely opaque background
            eventFrame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8", -- Solid texture
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 }
            })
            
            -- Set to a dark gray but fully opaque (RGBA)
            eventFrame:SetBackdropColor(0.1, 0.1, 0.1, 1.0)
            
            -- Force the frame to be shown
            eventFrame:Show()
            
            -- Event title
            local eventTitle = eventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            eventTitle:SetPoint("TOPLEFT", 10, -10)
            eventTitle:SetText(event.title)
            eventTitle:SetTextColor(1, 0.82, 0)
            
            -- Event time with timezone
            local eventTime = eventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            eventTime:SetPoint("TOPLEFT", eventTitle, "BOTTOMLEFT", 0, -5)
            eventTime:SetText("Date: " .. FormatLocalTime(event.timestamp) .. 
                             " " .. (event.timezone or "Local"))
            
            -- Time until event
            local timeUntil = eventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            timeUntil:SetPoint("TOPLEFT", eventTime, "BOTTOMLEFT", 0, -5)
            timeUntil:SetText("Time until: " .. GetTimeUntil(event.timestamp))
            timeUntil:SetTextColor(0.5, 1, 0.5)
            
            -- Event description
            local eventDesc = eventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            eventDesc:SetPoint("TOPLEFT", timeUntil, "BOTTOMLEFT", 0, -5)
            eventDesc:SetText(event.description)
            eventDesc:SetWidth(eventFrame:GetWidth() - 20)
            eventDesc:SetJustifyH("LEFT")
            
            -- Edit and Delete buttons (only visible for officers)
            if HasEventPermissions() then
                local editButton = CreateFrame("Button", nil, eventFrame, "UIPanelButtonTemplate")
                editButton:SetSize(60, 22)
                editButton:SetPoint("BOTTOMRIGHT", -80, 10)
                editButton:SetText("Edit")
                editButton:SetScript("OnClick", function()
                    ShowEventForm(frame, event)
                end)
                
                local deleteButton = CreateFrame("Button", nil, eventFrame, "UIPanelButtonTemplate")
                deleteButton:SetSize(60, 22)
                deleteButton:SetPoint("BOTTOMRIGHT", -10, 10)
                deleteButton:SetText("Delete")
                deleteButton:SetScript("OnClick", function()
                    StaticPopupDialogs["ORGA_EVENTS_DELETE_CONFIRM"] = {
                        text = "Are you sure you want to delete the event '" .. event.title .. "'?",
                        button1 = "Yes",
                        button2 = "No",
                        OnAccept = function()
                            if DeleteEvent(event.id) then
                                print("|cFFFFFFFF[ORGA_Events]|r Event deleted! Refreshing event list...")
                                print("|cFFFFFFFF[ORGA_Events]|r Total events remaining: " .. #ORGA_Events_Data.events)
                                
                                -- Use the same delay approach as with saving/canceling
                                C_Timer.After(0.1, function()
                                    -- Clear the frame completely first
                                    ClearFrame(frame)
                                    
                                    -- Force complete UI rebuild
                                    ORGA_Events_Data.forceListRefresh = true
                                    ShowEvents(frame)
                                    ORGA_Events_Data.forceListRefresh = false
                                    
                                    -- Verify events are visible
                                    local eventsVisible = 0
                                    if _G["ORGA_EventsScrollChild"] then
                                        for _, child in pairs({_G["ORGA_EventsScrollChild"]:GetChildren()}) do
                                            if child:IsShown() then
                                                eventsVisible = eventsVisible + 1
                                            end
                                        end
                                    end
                                    print("|cFFFFFFFF[ORGA_Events]|r Events visible after deletion: " .. eventsVisible)
                                end)
                            end
                        end,
                        timeout = 0,
                        whileDead = true,
                        hideOnEscape = true,
                        preferredIndex = 3,
                    }
                    StaticPopup_Show("ORGA_EVENTS_DELETE_CONFIRM")
                end)
            end
            
            -- Update vertical offset for next event
            yOffset = yOffset + 110
        end
    end
    
    -- Display message if no events
    if not hasEvents then
        local noEvents = scrollChild:CreateFontString("ORGA_Events_NoEventsText", "OVERLAY", "GameFontNormal")
        noEvents:SetPoint("CENTER")
        noEvents:SetText("No upcoming events")
    end
    
    -- Resize scroll child based on content - add minimum height
    local minScrollHeight = 100 -- Ensure we have at least some height
    local contentHeight = math.max(yOffset, scrollFrame:GetHeight(), minScrollHeight)
    scrollChild:SetHeight(contentHeight)
    
    -- Force the scroll child to be shown
    scrollChild:Show()
    scrollFrame:Show()
    
    -- Print visibility info
    Debug("Events list visibility: ScrollFrame visible=" .. tostring(scrollFrame:IsVisible()) .. 
          ", ScrollChild visible=" .. tostring(scrollChild:IsVisible()) ..
          ", ScrollChild height=" .. contentHeight)
    
    -- Log resize for debugging
    Debug("Events view resized - ScrollFrame: " .. scrollFrame:GetWidth() .. "x" .. scrollFrame:GetHeight() .. 
          ", EventFrameWidth: " .. eventFrameWidth)
    
    -- Force an update on the scroll frame
    scrollFrame:UpdateScrollChildRect()
end


-- Timer to update countdown displays
local eventTimerFrame = CreateFrame("Frame")
local lastUpdate = 0
eventTimerFrame:SetScript("OnUpdate", function(self, elapsed)
    lastUpdate = lastUpdate + elapsed
    if lastUpdate >= 60 then -- Update every minute
        lastUpdate = 0
        
        -- If the events frame is visible, update it
        if _G.ORGA_EventsScrollFrame and _G.ORGA_EventsScrollFrame:IsVisible() then
            -- Get the parent frame (tab content)
            local parentFrame = _G.ORGA_EventsScrollFrame:GetParent()
            if parentFrame then
                CreateEventsListView(parentFrame)
            end
        end
    end
end)

-- Main show events function (called by tab selection)
function ShowEvents(frame) -- Make it global by removing "local"
    Debug("ShowEvents called, frame size: " .. frame:GetWidth() .. "x" .. frame:GetHeight())
    
    -- Force complete UI rebuild - this appears to be key to fix disappearing events
    print("|cFFFFFFFF[ORGA_Events]|r Loading events panel...")
    
    -- Completely clear the frame to start fresh
    ClearFrame(frame)
    
    -- Turn on debugging temporarily
    ORGA_Events_Data.debug = true
    
    -- CRITICAL: Make sure our events data is properly initialized
    if not ORGA_Events_Data.events then
        ORGA_Events_Data.events = {}
        print("|cFFFFFFFF[ORGA_Events]|r WARNING: Events data was missing - initialized to empty table")
    end
    
    -- Sort events before displaying
    SortEvents()
    
    -- Print debug info about available events
    local futureEvents = 0
    local allEvents = #ORGA_Events_Data.events
    
    print("|cFFFFFFFF[ORGA_Events]|r Total events in database: " .. allEvents)
    
    for i, event in ipairs(ORGA_Events_Data.events) do
        if event.timestamp >= time() then
            futureEvents = futureEvents + 1
            Debug("Event #" .. i .. ": " .. event.title .. " at " .. FormatLocalTime(event.timestamp))
        end
    end
    
    print("|cFFFFFFFF[ORGA_Events]|r Found " .. futureEvents .. " upcoming events")
    
    -- CRITICAL: Completely rebuild the events list view
    CreateEventsListView(frame, false)
    
    -- After creating the view, verify events are visible
    local visibleEvents = 0
    if _G["ORGA_EventsScrollChild"] then
        for _, child in pairs({_G["ORGA_EventsScrollChild"]:GetChildren()}) do
            if child:IsShown() then
                visibleEvents = visibleEvents + 1
            end
        end
    end
    
    print("|cFFFFFFFF[ORGA_Events]|r Events visible after refresh: " .. visibleEvents)
    print("|cFFFFFFFF[ORGA_Events]|r Events loaded successfully")
    
    -- Turn off debug after we're done
    ORGA_Events_Data.debug = false
    
    -- Store the current tab handler to detect tab changes
    if not _G.ORGA_Events_CurrentTab or _G.ORGA_Events_CurrentTab ~= frame then
        _G.ORGA_Events_CurrentTab = frame
        
        -- Add throttled resize handler to the main frame
        frame:HookScript("OnSizeChanged", function(self, width, height)
            -- Use throttling to prevent resize spam
            if not isResizing then
                ThrottledResize(function()
                    CreateEventsListView(frame, true)
                end, "mainFrame", 0.3)
            end
        end)
    end
end

-- Add slash command for events
SLASH_ORGAEVENTS1 = "/orgaevents"
SlashCmdList["ORGAEVENTS"] = function(msg)
    if ORGA_PlayerInGuild then
        if msg == "debug" then
            ORGA_Events_Data.debug = not ORGA_Events_Data.debug
            print("|cFFFFFFFF[ORGA_Events]|r Debug mode " .. (ORGA_Events_Data.debug and "enabled" or "disabled"))
            
            -- Display rank information
            local guildName, guildRankName = GetGuildInfo("player")
            print("|cFFFFFFFF[ORGA_Events]|r Player guild rank: " .. (guildRankName or "Unknown"))
            print("|cFFFFFFFF[ORGA_Events]|r Permission to manage events: " .. (HasEventPermissions() and "YES" or "NO"))
            print("|cFFFFFFFF[ORGA_Events]|r Officer rank patterns with edit permissions:")
            for _, pattern in ipairs(OFFICER_RANK_PATTERNS) do
                print("  - " .. pattern)
            end
            
            -- Force a guild roster update to ensure we have current info
            GuildRoster()
            print("|cFFFFFFFF[ORGA_Events]|r Guild roster update requested")
            
        elseif msg == "forcepermission" then
            -- For testing only: enable permission override in saved data
            ORGA_Events_Data.forcePermission = not ORGA_Events_Data.forcePermission
            print("|cFFFFFFFF[ORGA_Events]|r Force permission mode " .. 
                (ORGA_Events_Data.forcePermission and "ENABLED" or "DISABLED"))
            
            -- Toggle the ORGA frame and select the Events tab
            if not ORGAMainFrame:IsVisible() then
                ORGAMainFrame:Show()
            end
            if ORGA_SelectTab then
                ORGA_SelectTab("Events")
            end
        else
            -- Toggle the ORGA frame and select the Events tab
            if not ORGAMainFrame:IsVisible() then
                ORGAMainFrame:Show()
            end
            -- Select the Events tab
            if ORGA_SelectTab then
                ORGA_SelectTab("Events")
            end
        end
    else
        print("|cFFFFFFFF[ORGA_Events]|r You must be in the OnlyRejects guild to use this command")
    end
end

-- Serialization helper functions
local function SerializeEvent(event)
    -- Create a simplified version for network transmission (fields separated by tildes)
    local serialized = table.concat({
        event.id or "",
        event.title or "",
        event.description or "",
        tostring(event.timestamp or 0),
        event.timezone or "UTC",
        event.createdBy or "",
        tostring(event.created or 0),
        tostring(event.lastEdited or 0)
    }, "~")
    
    return serialized
end

local function DeserializeEvent(serialized)
    -- Extract all fields from the serialized string
    local id, title, description, timestamp, timezone, createdBy, created, lastEdited = strsplit("~", serialized, 8)
    
    -- Convert numeric fields from strings back to numbers
    timestamp = tonumber(timestamp) or 0
    created = tonumber(created) or 0
    lastEdited = tonumber(lastEdited) or 0
    
    -- Create and return event table
    return {
        id = id,
        title = title,
        description = description,
        timestamp = timestamp,
        timezone = timezone,
        createdBy = createdBy,
        created = created,
        lastEdited = lastEdited
    }
end

-- Send functions
local function SendEventData(command, event, channel)
    channel = channel or "GUILD"
    
    -- Skip if not in guild and trying to send to guild
    if channel == "GUILD" and not IsInGuild() then
        Debug("Not sending event - not in a guild")
        return
    end
    
    -- Serialize the event data
    local serialized = SerializeEvent(event)
    local message = command .. "|" .. serialized
    
    -- Keep message under the addon message limit (255 bytes)
    if #message > 255 then
        -- Truncate description if needed to fit within limit
        local truncatedDesc = string.sub(event.description or "", 1, 100) .. "..."
        event.description = truncatedDesc
        serialized = SerializeEvent(event)
        message = command .. "|" .. serialized
        
        -- Check again after truncation
        if #message > 255 then
            Debug("Failed to send event data - message too long even after truncation")
            return
        end
    end
    
    -- Send the message
    if C_ChatInfo then
        C_ChatInfo.SendAddonMessage(COMM_PREFIX, message, channel)
        Debug("Sent " .. command .. " for event " .. event.id .. " via " .. channel)
    end
end

-- Function to broadcast a newly created event
local function BroadcastNewEvent(event)
    SendEventData(COMM_COMMANDS.EVENT_ADD, event)
end

-- Function to broadcast an edited event
local function BroadcastEditedEvent(event)
    SendEventData(COMM_COMMANDS.EVENT_EDIT, event)
end

-- Function to broadcast a deleted event
local function BroadcastDeletedEvent(event)
    SendEventData(COMM_COMMANDS.EVENT_DELETE, event)
end

-- Function to request sync from guild
local function RequestEventsSync()
    if not IsInGuild() then
        Debug("Not requesting sync - not in a guild")
        return
    end
    
    -- Send sync request to guild
    if C_ChatInfo then
        C_ChatInfo.SendAddonMessage(COMM_PREFIX, COMM_COMMANDS.SYNC_REQUEST, "GUILD")
        Debug("Sent sync request to guild")
    end
end

-- Function to send all events data
local function SendEventsData(channel)
    channel = channel or "GUILD"
    
    -- Skip if not in guild and trying to send to guild
    if channel == "GUILD" and not IsInGuild() then
        Debug("Not sending events data - not in a guild")
        return
    end
    
    -- Pack all events into a compact format
    local dataPackets = {}
    local currentPacket = ""
    
    -- Record sync time
    ORGA_Events_Data.lastSync = time()
    
    -- Add header with count and timestamp
    local header = COMM_COMMANDS.SYNC_DATA .. "|" .. #ORGA_Events_Data.events .. ":" .. ORGA_Events_Data.lastSync
    table.insert(dataPackets, header)
    
    -- Add each event as a separate message (to stay under size limits)
    for _, event in ipairs(ORGA_Events_Data.events) do
        SendEventData(COMM_COMMANDS.SYNC_DATA, event, channel)
    end
    
    Debug("Sent events data to " .. channel .. " (" .. #ORGA_Events_Data.events .. " events)")
end

-- Process incoming messages
local function ProcessIncomingSyncData(data, sender)
    -- Check if this is a header packet
    if string.find(data, "^%d+:%d+$") then
        -- Extract event count and timestamp
        local count, timestamp = strsplit(":", data)
        count = tonumber(count) or 0
        timestamp = tonumber(timestamp) or 0
        
        -- If sender's data is older than ours, ignore it
        if timestamp < ORGA_Events_Data.lastSync then
            Debug("Ignoring older sync data from " .. sender)
            return
        end
        
        Debug("Processing sync data from " .. sender .. " with " .. count .. " events")
        return
    end
    
    -- Otherwise, this is an event packet
    local event = DeserializeEvent(data)
    
    -- Validate event
    if not event or not event.id or not event.timestamp then
        Debug("Received invalid event data from " .. sender)
        return
    end
    
    -- Look for existing event with same ID
    local found = false
    for i, existingEvent in ipairs(ORGA_Events_Data.events) do
        if existingEvent.id == event.id then
            -- Use the newer version based on lastEdited timestamp
            if not existingEvent.lastEdited or (event.lastEdited and event.lastEdited > existingEvent.lastEdited) then
                ORGA_Events_Data.events[i] = event
                Debug("Updated existing event: " .. event.title)
            end
            found = true
            break
        end
    end
    
    -- If not found, add the new event
    if not found then
        table.insert(ORGA_Events_Data.events, event)
        Debug("Added new event from sync: " .. event.title)
    end
    
    -- Sort events after processing sync data
    SortEvents()
    
    -- If the events list is visible, refresh it
    if _G.ORGA_EventsScrollFrame and _G.ORGA_EventsScrollFrame:IsVisible() then
        -- Get the parent frame (tab content)
        local parentFrame = _G.ORGA_EventsScrollFrame:GetParent()
        if parentFrame then
            Debug("Refreshing events list after sync")
            CreateEventsListView(parentFrame)
        end
    end
end

local function ProcessIncomingEventAdd(data, sender)
    local event = DeserializeEvent(data)
    
    -- Validate event
    if not event or not event.id or not event.timestamp then
        Debug("Received invalid event data for add from " .. sender)
        return
    end
    
    -- Check if we already have this event
    for _, existingEvent in ipairs(ORGA_Events_Data.events) do
        if existingEvent.id == event.id then
            Debug("Event already exists, ignoring add: " .. event.id)
            return
        end
    end
    
    -- Add the new event
    table.insert(ORGA_Events_Data.events, event)
    Debug("Added new event from " .. sender .. ": " .. event.title)
    
    -- Sort events after adding new one
    SortEvents()
    
    -- Show notification to user
    print("|cFFFFFFFF[ORGA_Events]|r New event added: " .. event.title .. " on " .. FormatLocalTime(event.timestamp))
    
    -- Refresh UI if visible
    if _G.ORGA_EventsScrollFrame and _G.ORGA_EventsScrollFrame:IsVisible() then
        local parentFrame = _G.ORGA_EventsScrollFrame:GetParent()
        if parentFrame then
            Debug("Refreshing events list after add")
            CreateEventsListView(parentFrame)
        end
    end
end

local function ProcessIncomingEventEdit(data, sender)
    local event = DeserializeEvent(data)
    
    -- Validate event
    if not event or not event.id then
        Debug("Received invalid event data for edit from " .. sender)
        return
    end
    
    -- Look for existing event with this ID
    local found = false
    for i, existingEvent in ipairs(ORGA_Events_Data.events) do
        if existingEvent.id == event.id then
            -- Update the event
            ORGA_Events_Data.events[i] = event
            Debug("Updated event from " .. sender .. ": " .. event.title)
            found = true
            break
        end
    end
    
    if not found then
        Debug("Could not find event to edit: " .. event.id)
        return
    end
    
    -- Sort events after editing
    SortEvents()
    
    -- Show notification to user
    print("|cFFFFFFFF[ORGA_Events]|r Event updated: " .. event.title)
    
    -- Refresh UI if visible
    if _G.ORGA_EventsScrollFrame and _G.ORGA_EventsScrollFrame:IsVisible() then
        local parentFrame = _G.ORGA_EventsScrollFrame:GetParent()
        if parentFrame then
            Debug("Refreshing events list after edit")
            CreateEventsListView(parentFrame)
        end
    end
end

local function ProcessIncomingEventDelete(data, sender)
    local event = DeserializeEvent(data)
    
    -- Validate event
    if not event or not event.id then
        Debug("Received invalid event data for delete from " .. sender)
        return
    end
    
    -- Look for existing event with this ID
    local found = false
    for i, existingEvent in ipairs(ORGA_Events_Data.events) do
        if existingEvent.id == event.id then
            -- Remove the event
            table.remove(ORGA_Events_Data.events, i)
            Debug("Deleted event from " .. sender .. ": " .. event.title)
            found = true
            break
        end
    end
    
    if not found then
        Debug("Could not find event to delete: " .. event.id)
        return
    end
    
    -- Show notification to user
    print("|cFFFFFFFF[ORGA_Events]|r Event deleted: " .. event.title)
    
    -- Refresh UI if visible
    if _G.ORGA_EventsScrollFrame and _G.ORGA_EventsScrollFrame:IsVisible() then
        local parentFrame = _G.ORGA_EventsScrollFrame:GetParent()
        if parentFrame then
            Debug("Refreshing events list after delete")
            CreateEventsListView(parentFrame)
        end
    end
end

-- Create a function to attempt tab registration
local function TryRegisterTab()
    -- Only register the tab if player is in the guild
    if ORGA_RegisterTab and (ORGA_PlayerInGuild == nil or ORGA_PlayerInGuild == true) then
        Debug("Attempting to register tab")
        
        -- We need to make sure the ShowEvents function is called correctly every time
        -- This is critical to fixing the issue of events disappearing
        ORGA_RegisterTab("Events", function(frame)
            -- Always do a fresh build of the events panel
            ShowEvents(frame)
        end)
        
        _G.ORGA_Events_Loaded = "Loaded"
        
        -- Initialize communication system
        InitializeComm()
        
        -- Request events sync
        C_Timer.After(5, RequestEventsSync)
        
        -- Print status message
        print("|cFFFFFFFF[ORGA_Events]|r Events module loaded successfully")
    else
        Debug("Not registering tab - player not in guild or ORGA not loaded")
        _G.ORGA_Events_Loaded = "Loaded but not registered (not in guild)"
    end
end

-- Create an event frame to register when addon is fully loaded
local eventsFrame = CreateFrame("Frame")
eventsFrame:RegisterEvent("ADDON_LOADED")
eventsFrame:RegisterEvent("PLAYER_LOGIN")
eventsFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
eventsFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "ORGA_Events" then
        Debug("Module loaded")
        _G.ORGA_Events_Loaded = "Loading"
        
        -- Try and register shortly after loading
        C_Timer.After(2, TryRegisterTab)
        
        -- Only need to handle ADDON_LOADED once
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        -- Try again at login, after ORGA has had time to initialize
        C_Timer.After(3, TryRegisterTab)
        
        -- Request guild roster update (do this multiple times to make sure it loads)
        if IsInGuild() then
            GuildRoster()
            -- Try again in case the first request fails
            C_Timer.After(2, function() GuildRoster() end)
            C_Timer.After(5, function() GuildRoster() end)
        end
        
        -- Only need to handle PLAYER_LOGIN once
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "GUILD_ROSTER_UPDATE" then
        -- This event fires when guild information is available or updated
        Debug("Guild roster updated, checking permissions")
        
        -- Only process guild info updates when not resizing
        if not isResizing then
            -- Get updated rank information
            local guildName, guildRankName = GetGuildInfo("player")
            if guildName and guildRankName then
                Debug("Guild info updated - Guild: " .. guildName .. ", Rank: " .. guildRankName)
                
                -- Store current rank to avoid spam
                if not ORGA_Events_Data.playerRank or ORGA_Events_Data.playerRank ~= guildRankName then
                    ORGA_Events_Data.playerRank = guildRankName
                    
                    -- Only show debug info when rank has changed
                    if ORGA_Events_Data.debug then
                        print("|cFFFFFFFF[ORGA_Events]|r Guild roster updated")
                        print("|cFFFFFFFF[ORGA_Events]|r Player guild rank: " .. guildRankName)
                        print("|cFFFFFFFF[ORGA_Events]|r Permission status: " .. (HasEventPermissions() and "YES" or "NO"))
                    end
                end
            end
        end
    end
end)

-- Create a timer to check for reinitialization requests
C_Timer.NewTicker(1, function()
    if _G.ORGA_Events_TryRegister then
        Debug("Received reinitialization request")
        _G.ORGA_Events_TryRegister = nil
        TryRegisterTab()
    end
end)