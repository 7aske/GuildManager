-- Guild Manager Main Lua File
GuildManager = {}
GuildManager.version = "1.0.0"

-- Database for saved variables
GuildManagerDB = GuildManagerDB or {}

-- Cache for guild members
local guildMembers = {}
local currentSort = {
    column = "name",
    ascending = true
}
local searchText = ""
local selectedMember
local showOfflineMembers = true
local myRankIndex
local guildName
local numDisplayed = 15

-- Initialize the addon
function GuildManager:OnLoad(frame)
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("GUILD_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_GUILD_UPDATE")

    -- Set up slash commands
    SLASH_GUILDMANAGER1 = "/gman"
    SLASH_GUILDMANAGER2 = "/guildmanager"
    SlashCmdList["GUILDMANAGER"] = function()
        GuildManager:ToggleFrame()
    end

    -- Initialize showOfflineMembers from the game's current setting
    showOfflineMembers = GetGuildRosterShowOffline()
    guildName, _, myRankIndex = GetGuildInfo("player")

    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Guild Manager|r v" .. self.version .. " loaded. Type /gman to open.")
end

-- Event handler
function GuildManager:OnEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        self:RequestGuildRoster()
    elseif event == "GUILD_ROSTER_UPDATE" then
        self:UpdateGuildRoster()
    elseif event == "PLAYER_GUILD_UPDATE" then
        self:RequestGuildRoster()
    end
end

-- Request guild roster update
function GuildManager:RequestGuildRoster()
    if IsInGuild() then
        GuildRoster()
    end
end

-- Update guild roster data
function GuildManager:UpdateGuildRoster()
    guildMembers = {}

    if not IsInGuild() then
        return
    end

    local numTotalMembers = GetNumGuildMembers()
    local numOnlineMembers = 0

    for i = 1, numTotalMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(i)
        local yearsOffline, monthsOffline, daysOffline, hoursOffline = GetGuildRosterLastOnline(i)
        if yearsOffline == nil then yearsOffline = 0 end
        if monthsOffline == nil then monthsOffline = 0 end
        if daysOffline == nil then daysOffline = 0 end
        if hoursOffline == nil then hoursOffline = 0 end
        if online then
            numOnlineMembers = numOnlineMembers + 1
        end

        if name then
            -- Remove server name if present
            name = strsplit("-", name)

            table.insert(guildMembers, {
                index = i,
                name = name or "",
                rank = rank or "",
                rankIndex = rankIndex or 0,
                level = level or 0,
                class = class or "",
                classFileName = classFileName or "",
                zone = zone or "",
                note = note or "",
                officernote = officernote or "",
                online = online,
                status = status or "",
                lastOnline = yearsOffline * 365 * 24 * 60 + monthsOffline * 30 * 24 * 60 + daysOffline * 24 * 60 + hoursOffline * 60,
                lastOnlineText = self:FormatLastOnline(online, yearsOffline, monthsOffline, daysOffline, hoursOffline)
            })
        end
    end

    self:SortAndFilterMembers()

    -- If edit dialog is open, refresh it with the latest data for the selected member
    if GuildManagerEditDialog and GuildManagerEditDialog:IsShown() and selectedMember and selectedMember.name then
        for _, m in ipairs(guildMembers) do
            if m.name == selectedMember.name then
                selectedMember = m
                self:ShowEditDialog(selectedMember)
                break
            end
        end
    end
    GuildManagerFrameMemberCount:SetText("|cFFFFFFFF" .. numTotalMembers .. "|r" .. " Guild Members (|cFFFFFFFF" .. numOnlineMembers .. "|r |cFF00FF00Online|r)")
end

function GuildManager:FormatLastOnline(online, yearsOffline, monthsOffline, daysOffline, hoursOffline)
    if online then
        return "Online"
    else
        if yearsOffline and yearsOffline > 0 then
            return yearsOffline .. " year" .. (yearsOffline > 1 and "s" or "") .. " ago"
        elseif monthsOffline and monthsOffline > 0 then
            return monthsOffline .. " month" .. (monthsOffline > 1 and "s" or "") .. " ago"
        elseif daysOffline and daysOffline > 0 then
            return daysOffline .. " day" .. (daysOffline > 1 and "s" or "") .. " ago"
        elseif hoursOffline and hoursOffline > 0 then
            return hoursOffline .. " hour" .. (hoursOffline > 1 and "s" or "") .. " ago"
        else
            return "< an hour ago"
        end
    end
end

-- Sort members by column
function GuildManager:SortMembers(column)
    if currentSort.column == column then
        currentSort.ascending = not currentSort.ascending
    else
        currentSort.column = column
        currentSort.ascending = true
    end

    self:SortAndFilterMembers()
    self:UpdateHeaderButtons()
end

-- Apply sorting and filtering
function GuildManager:SortAndFilterMembers()
    -- Filter by search text
    local filteredMembers = {}
    local search = string.lower(searchText)

    for _, member in ipairs(guildMembers) do
        -- Filter by search text
        if search == "" or
           string.find(string.lower(member.name), search, 1, true) or
           string.find(string.lower(member.note), search, 1, true) or
           string.find(string.lower(member.officernote), search, 1, true) or
           string.find(string.lower(member.rank), search, 1, true) or
           string.find(string.lower(member.class), search, 1, true) then
            table.insert(filteredMembers, member)
        end
    end

    -- Sort filtered members
    table.sort(filteredMembers, function(a, b)
        local column = currentSort.column
        local aVal, bVal

        if column == "name" then
            aVal, bVal = a.name, b.name
        elseif column == "rank" then
            aVal, bVal = a.rankIndex, b.rankIndex
        elseif column == "note" then
            aVal, bVal = a.note, b.note
        elseif column == "officernote" then
            aVal, bVal = a.officernote, b.officernote
        elseif column == "level" then
            aVal, bVal = a.level, b.level
        elseif column == "class" then
            aVal, bVal = a.class, b.class
        elseif column == "lastonline" then
            if a.online and not b.online then
                return currentSort.ascending
            elseif not a.online and b.online then
                return not currentSort.ascending
            end
            aVal, bVal = a.lastOnline, b.lastOnline
        else
            aVal, bVal = a.name, b.name
        end

        if currentSort.ascending then
            return aVal < bVal
        else
            return aVal > bVal
        end
    end)

    self:UpdateScrollFrame(filteredMembers)
end

-- Update the scroll frame with filtered/sorted members
function GuildManager:UpdateScrollFrame(members)
    if not GuildManagerFrame then
        DEFAULT_CHAT_FRAME:AddMessage("Guild Manager ERROR: GuildManagerFrame not found!")
        return
    end

    local scrollFrame = GuildManagerScrollFrame
    if not scrollFrame then
        DEFAULT_CHAT_FRAME:AddMessage("Guild Manager ERROR: GuildManagerScrollFrame not found!")
        return
    end

    local offset = FauxScrollFrame_GetOffset(scrollFrame)

    FauxScrollFrame_Update(scrollFrame, math.max(numDisplayed + 1, #members), numDisplayed, 22)

    for i = 1, numDisplayed do
        local index = offset + i
        local button = _G["GuildManagerEntry"..i]

        if not button then
            DEFAULT_CHAT_FRAME:AddMessage("Guild Manager ERROR: Button " .. i .. " not found!")
        else
            -- Ensure button responds to left and right clicks and route to OnEntryClick
            button:RegisterForClicks("AnyUp")
            button:SetScript("OnMouseUp", function(self, mouseButton)
                GuildManager:OnEntryClick(self, mouseButton)
            end)

            -- Check if button's text elements are initialized
            if not button.nameText then
                DEFAULT_CHAT_FRAME:AddMessage("Guild Manager ERROR: Button " .. i .. " nameText not initialized!")
                -- Try to initialize manually
                button.nameText = _G["GuildManagerEntry"..i.."Name"]
                button.levelText = _G["GuildManagerEntry"..i.."Level"]
                button.classText = _G["GuildManagerEntry"..i.."Class"]
                button.rankText = _G["GuildManagerEntry"..i.."Rank"]
                button.noteText = _G["GuildManagerEntry"..i.."Note"]
                button.officerNoteText = _G["GuildManagerEntry"..i.."OfficerNote"]
                button.lastOnlineText = _G["GuildManagerEntry"..i.."LastOnline"]
            end

            if index <= #members then
                local member = members[index]

                -- Store the member data on the button for later access
                button.memberData = member

                -- Set name with class color
                button.nameText:SetText(ClassColoredText(member.name, member.classFileName))

                -- Set level
                if member.level == MAX_PLAYER_LEVEL then
                    button.levelText:SetText(member.level)
                else
                    button.levelText:SetText(ColoredText(member.level, 0.5, 0.5, 0.5))
                end

                -- Set class with class color
                button.classText:SetText(ClassColoredText(member.class, member.classFileName))

                -- Set rank (role)
                button.rankText:SetText(member.rank)

                -- Set public note
                if member.online then
                    button.noteText:SetText(ColoredText(member.note, 1, 1, 1))
                else
                    button.noteText:SetText(ColoredText(member.note, 0.5, 0.5, 0.5))
                end

                -- Set officer note (only visible if you have permission)
                if member.online then
                    button.officerNoteText:SetText(ColoredText(member.officernote, 1, 1, 1))
                else
                    button.officerNoteText:SetText(ColoredText(member.officernote, 0.5, 0.5, 0.5))
                end

                if member.online then
                    button.lastOnlineText:SetText(ColoredText(member.lastOnlineText, 1, 1, 1))
                    else
                    button.lastOnlineText:SetText(ColoredText(member.lastOnlineText, 0.5, 0.5, 0.5))
                end


                local alpha = member.online and 1.0 or 0.5
                button.nameText:SetAlpha(alpha)
                button.levelText:SetAlpha(alpha)
                button.classText:SetAlpha(alpha)
                button.rankText:SetAlpha(alpha)
                button.noteText:SetAlpha(alpha)
                button.officerNoteText:SetAlpha(alpha)
                button.lastOnlineText:SetAlpha(alpha)

                button:Show()
            else
                button.memberData = nil
                button:Hide()
            end
        end
    end
end

-- Toggle the main frame
function GuildManager:ToggleFrame()
    if not IsInGuild() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000You are not in a guild!|r")
        return
    end

    if GuildManagerFrame:IsShown() then
        GuildManagerFrame:Hide()
    else
        GuildManagerFrame:Show()
        GuildManagerFrameTitle:SetText("Guild Manager - " .. (guildName or "N/A"))

        -- Sync the checkbox with the game's current setting
        showOfflineMembers = GetGuildRosterShowOffline()
        if GuildManagerFrameShowOfflineCheckbox then
            GuildManagerFrameShowOfflineCheckbox:SetChecked(showOfflineMembers)
        end

        self:RequestGuildRoster()
        -- Force an immediate update if we already have data
        if #guildMembers > 0 then
            self:SortAndFilterMembers()
        end
    end
end

-- Search function
function GuildManager:SetSearchText(text)
    searchText = text or ""
    FauxScrollFrame_SetOffset(GuildManagerScrollFrame, 0)
    self:SortAndFilterMembers()
end

-- Refresh button handler
function GuildManager:RefreshRoster()
    self:RequestGuildRoster()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Guild Manager:|r Roster refreshed.")
end

-- Get sort indicator
function GuildManager:GetSortIndicator(column)
    if currentSort.column == column then
        return currentSort.ascending and " ^" or " v"
    end
    return ""
end

-- Update header button texts with sort indicators
function GuildManager:UpdateHeaderButtons()
    if not GuildManagerFrame then return end

    local headers = {
        {name = "Name", column = "name", button = GuildManagerFrameHeaderFrameNameHeader},
        {name = "L", column = "level", button = GuildManagerFrameHeaderFrameLevelHeader},
        {name = "Class", column = "class", button = GuildManagerFrameHeaderFrameClassHeader},
        {name = "Rank", column = "rank", button = GuildManagerFrameHeaderFrameRankHeader},
        {name = "Note", column = "note", button = GuildManagerFrameHeaderFrameNoteHeader},
        {name = "Officer's Note", column = "officernote", button = GuildManagerFrameHeaderFrameOfficerNoteHeader},
        {name = "Last Online", column = "lastonline", button = GuildManagerFrameHeaderFrameLastOnlineHeader}
    }

    for _, header in ipairs(headers) do
        if header.button then
            header.button:SetText(header.name .. self:GetSortIndicator(header.column))
        end
    end
end

-- Handle entry click (left-click preserves existing behavior; right-click opens standard Blizzard guild menu)
function GuildManager:OnEntryClick(button, mouseButton)
    if not button or not button.memberData then
        return
    end

    -- Right-click: show Blizzard guild member context menu
    if mouseButton == "RightButton" then
        GuildManager:ShowGuildMemberMenu(button)
        return
    end

    -- Left-click (default behavior)
    selectedMember = button.memberData
    self:ShowEditDialog(selectedMember)
end

-- Show the standard Blizzard guild member right-click menu for a given entry button
function GuildManager:ShowGuildMemberMenu(button)
    if not button or not button.memberData then return end
    if not button.memberData.online then
        return
    end

    FriendsFrame_ShowDropdown(button.memberData.name, true)
end

-- Show edit dialog
function GuildManager:ShowEditDialog(member)
    if not GuildManagerEditDialog then
        DEFAULT_CHAT_FRAME:AddMessage("Guild Manager ERROR: Edit dialog not found!")
        return
    end

    -- Use the freshest member object from guildMembers (match by name) if available
    if member and member.name then
        for _, m in ipairs(guildMembers) do
            if m.name == member.name then
                member = m
                break
            end
        end
    end

    -- update global selectedMember reference
    selectedMember = member

    -- Set member info (guard nils)
    GuildManagerEditDialogTitle:SetText("Edit " .. (member and member.name or ""))
    GuildManagerEditDialogNameValue:SetText(member and member.name or "")
    GuildManagerEditDialogRankValue:SetText(member and member.rank or "")

    -- Set notes in edit boxes (access the EditBox inside the ScrollFrame)
    local publicNoteEdit = GuildManagerEditDialogPublicNoteScrollEdit
    local officerNoteEdit = GuildManagerEditDialogOfficerNoteScrollEdit

    if publicNoteEdit then
        local incomingText = (member and member.note) or ""
        local existingText = publicNoteEdit:GetText()
        if existingText == "" or not existingText == incomingText then
            publicNoteEdit:SetText(incomingText)
        end
    end

    if officerNoteEdit then
        local incomingText = (member and member.officernote) or ""
        local existingText = officerNoteEdit:GetText()
        if existingText == "" or not existingText == incomingText then
            officerNoteEdit:SetText(incomingText)
        end
    end

    -- Update Promote/Demote button enabled state
    do
        -- find max rankIndex present in cached guildMembers
        local maxRankIndex = 0
        for _, m in ipairs(guildMembers) do
            if m.rankIndex and m.rankIndex > maxRankIndex then
                maxRankIndex = m.rankIndex
            end
        end

        local promoteBtn = GuildManagerEditDialogPromoteButton
        local demoteBtn = GuildManagerEditDialogDemoteButton

        if promoteBtn then
            if member and member.rankIndex and member.rankIndex > 0 and myRankIndex < member.rankIndex - 1 then
                promoteBtn:Enable()
            else
                promoteBtn:Disable()
            end
        end

        if demoteBtn then
            if member and member.rankIndex and member.rankIndex < maxRankIndex then
                demoteBtn:Enable()
            else
                demoteBtn:Disable()
            end
        end
    end

    local canRemove, _ = HasPermission(member.name)
    if not canRemove then
        GuildManagerEditDialogRemoveButton:Disable()
    else
        GuildManagerEditDialogRemoveButton:Enable()
    end

    -- Update Invite button enabled state
    if not member.online or member.name == UnitName("player") then
        GuildManagerEditDialogInviteButton:Disable()
    else
        GuildManagerEditDialogInviteButton:Enable()
    end

    -- Show the dialog
    GuildManagerEditDialog:Show()
    GuildManagerEditDialog:ClearAllPoints()
    GuildManagerEditDialog:SetPoint("TOPLEFT", GuildManagerFrame, "TOPRIGHT", "0", "0")
    GuildManagerEditDialog:SetUserPlaced(false)
end

-- Promote selected member (calls Blizzard API)
function GuildManager:PromoteSelectedMember()
    if not selectedMember then return end
    if not IsInGuild() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Guild Manager: You are not in a guild.|r")
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage("Guild Manager: Promoting " .. selectedMember.name)
    -- Call the Blizzard API to promote (name is used here)
    -- Note: the default API is GuildPromote(name) in classic/older APIs
    pcall(function() GuildPromote(selectedMember.name) end)

    -- Refresh roster and update dialog shortly after
    self:RequestGuildRoster()
    -- schedule a small delay to allow server update, then refresh dialog display
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            -- Update selectedMember info from latest guildMembers (match by name)
            for _, m in ipairs(guildMembers) do
                if m.name == selectedMember.name then
                    selectedMember = m
                    GuildManagerEditDialogRankValue:SetText(m.rank)
                    break
                end
            end
            -- update button states
            if GuildManagerEditDialog:IsShown() then
                GuildManager:ShowEditDialog(selectedMember)
            end
        end)
    end
end

-- Demote selected member (calls Blizzard API)
function GuildManager:DemoteSelectedMember()
    if not selectedMember then return end
    if not IsInGuild() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Guild Manager: You are not in a guild.|r")
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage("Guild Manager: Demoting " .. selectedMember.name)
    pcall(function() GuildDemote(selectedMember.name) end)

    self:RequestGuildRoster()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            for _, m in ipairs(guildMembers) do
                if m.name == selectedMember.name then
                    selectedMember = m
                    GuildManagerEditDialogRankValue:SetText(m.rank)
                    break
                end
            end
            if GuildManagerEditDialog:IsShown() then
                GuildManager:ShowEditDialog(selectedMember)
            end
        end)
    end
end

-- Save member edit
function GuildManager:SaveMemberEdit()
    if not selectedMember then
        return
    end

    -- Get the EditBox inside the ScrollFrame
    local publicNoteEdit = GuildManagerEditDialogPublicNoteScrollEdit
    local officerNoteEdit = GuildManagerEditDialogOfficerNoteScrollEdit

    if not publicNoteEdit or not officerNoteEdit then
        DEFAULT_CHAT_FRAME:AddMessage("Guild Manager ERROR: Edit boxes not found!")
        return
    end

    local publicNote = publicNoteEdit:GetText()
    local officerNote = officerNoteEdit:GetText()

    -- Find the current member index from the refreshed guildMembers (safer than trusting stored index)
    local memberIndex = selectedMember.index
    for _, m in ipairs(guildMembers) do
        if m.name == selectedMember.name then
            memberIndex = m.index
            break
        end
    end

    if memberIndex then
        -- Use WoW API to set guild member notes (requires permission)
        GuildRosterSetPublicNote(memberIndex, publicNote)
        GuildRosterSetOfficerNote(memberIndex, officerNote)

        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Guild Manager:|r Updated notes for " .. selectedMember.name)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Guild Manager:|r Could not find member index to save notes.")
    end

    -- Hide dialog and refresh
    GuildManagerEditDialog:Hide()
    self:RequestGuildRoster()
end

-- Toggle showing offline members
function GuildManager:ToggleShowOffline(checked)
    showOfflineMembers = checked

    -- Use the game's API to show/hide offline members in the actual guild roster data
    SetGuildRosterShowOffline(checked)

    -- Request a fresh roster update to get the new data
    self:RequestGuildRoster()
end

-- Remove member from guild
function GuildManager:RemoveMemberFromGuild()
    if not selectedMember then return end
    if not IsInGuild() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Guild Manager: You are not in a guild.|r")
        return
    end

    -- Show confirmation dialog
    StaticPopupDialogs["GUILDMANAGER_REMOVE_CONFIRM"] = {
        text = "Are you sure you want to remove " .. selectedMember.name .. " from the guild?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            DEFAULT_CHAT_FRAME:AddMessage("Guild Manager: Removing " .. selectedMember.name .. " from guild")
            pcall(function() GuildUninvite(selectedMember.name) end)
            GuildManagerEditDialog:Hide()
            GuildManager:RequestGuildRoster()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("GUILDMANAGER_REMOVE_CONFIRM")
end

-- Invite member to group
function GuildManager:InviteMemberToGroup()
    if not selectedMember then return end

    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Guild Manager:|r Inviting " .. selectedMember.name .. " to group")
    InviteUnit(selectedMember.name)
end

-- New: Show 'Add Member' dialog to invite a player to the guild
function GuildManager:ShowAddMemberDialog()
    -- Create a simple StaticPopup dialog for adding a member if it doesn't exist
    if not StaticPopupDialogs["GUILDMANAGER_ADD_MEMBER"] then
        StaticPopupDialogs["GUILDMANAGER_ADD_MEMBER"] = {
            text = "Invite player to the guild:",
            button1 = "Invite",
            button2 = "Cancel",
            hasEditBox = true,
            maxLetters = 128,
            OnAccept = function(self)
                local name = self.editBox:GetText()
                if name and name ~= "" then
                    GuildManager:AddMember(name)
                else
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Guild Manager:|r No name entered.")
                end
            end,
            OnShow = function(self)
                self.editBox:SetText("")
                self.editBox:ClearFocus()
            end,
            OnHide = function(self)
                self.editBox:SetText("")
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    StaticPopup_Show("GUILDMANAGER_ADD_MEMBER")
end

-- New: Add member (invite to guild) by name
function GuildManager:AddMember(name)
    if not name or name == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Guild Manager:|r Invalid name.")
        return
    end

    if not IsInGuild() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Guild Manager:|r You are not in a guild.")
        return
    end

    -- Trim whitespace
    name = name:gsub("^%s+", ""):gsub("%s+$", "")

    -- Basic validation: prevent inviting yourself
    if name == UnitName("player") then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Guild Manager:|r You cannot invite yourself.")
        return
    end

    -- Attempt to invite using the Blizzard API. Different WoW versions expose different functions.
    local ok, err = pcall(function()
        if GuildInvite then
            GuildInvite(name)
        elseif GuildInviteByName then
            GuildInviteByName(name)
        elseif C_GuildInfo and C_GuildInfo.Invite then
            C_GuildInfo.Invite(name)
        else
            error("No guild invite API available in this client version.")
        end
    end)

    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Guild Manager:|r Failed to invite " .. name .. ": " .. tostring(err))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Guild Manager:|r Invitation sent to " .. name)
    end
end

function HasPermission(targetName)
    if not IsInGuild() then
        return false, "Not in a guild."
    end

    -- Get the target's rank index
    local targetRankIndex
    for i = 1, GetNumGuildMembers() do
        local name, _, rankIndex = GetGuildRosterInfo(i)
        if name == targetName then
            targetRankIndex = rankIndex
            break
        end
    end

    if targetRankIndex == nil then
        return false, "Target not found in roster or offline."
    end

    -- Guild Master (rank 0) can always remove members
    if myRankIndex == 0 then
        return true, "Guild Master."
    end

    -- Check if player has the 'remove' flag for their rank
    -- The specific flag index/name may change with API updates.
    -- Historically, flag 12 or a similar index was "can remove players".
    -- You need to inspect the table returned by C_GuildInfo.GuildControlGetRankFlags(myRankIndex)
    -- to find the correct key for 'remove' permission in the current API version.
    -- Assuming a generic 'canRemove' flag exists in the returned table:
    -- local rankFlags = C_GuildInfo.GuildControlGetRankFlags(myRankIndex)
    -- local hasRemovePermission = rankFlags and rankFlags.canRemove

    -- A more direct check is often comparing ranks. A higher rank index (lower rank) cannot kick a lower rank index (higher rank).
    if myRankIndex < targetRankIndex then
        -- This generally implies you have a higher rank and thus implicitly the permission (if the GM set it up this way)
        return true, "Higher rank."
    else
        return false, "Insufficient rank."
    end
end

function ClassColoredText(text, classFileName)
    local classColor = RAID_CLASS_COLORS[classFileName]
    if classColor then
        local colorStr = string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
        return "|cff" .. colorStr .. text .. "|r"
    else
        return text
    end
end

function ColoredText(text, r, g, b, a)
    if not text then
        return ""
    end
    if r == nil and g == nil and b == nil then
        return text
    end
    if a == nil then a = 1.0 end
    local colorStr = string.format("%02x%02x%02x%02x", a * 255, r * 255, g * 255, b * 255)
    return "|c" .. colorStr .. text .. "|r"
end
