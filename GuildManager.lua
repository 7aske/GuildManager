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
local selectedMember = nil

-- Initialize the addon
function GuildManager:OnLoad(frame)
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("GUILD_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_GUILD_UPDATE")

    -- Set up slash commands
    SLASH_GUILDMANAGER1 = "/gman"
    SLASH_GUILDMANAGER2 = "/guildmanager"
    SlashCmdList["GUILDMANAGER"] = function(msg)
        GuildManager:ToggleFrame()
    end

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

    for i = 1, numTotalMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(i)

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
                status = status or ""
            })
        end
    end

    self:SortAndFilterMembers()
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
        if search == "" or
           string.find(string.lower(member.name), search, 1, true) or
           string.find(string.lower(member.note), search, 1, true) or
           string.find(string.lower(member.officernote), search, 1, true) or
           string.find(string.lower(member.rank), search, 1, true) then
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

    DEFAULT_CHAT_FRAME:AddMessage("Guild Manager: UpdateScrollFrame called with " .. #members .. " members")

    local scrollFrame = GuildManagerScrollFrame
    if not scrollFrame then
        DEFAULT_CHAT_FRAME:AddMessage("Guild Manager ERROR: GuildManagerScrollFrame not found!")
        return
    end

    local offset = FauxScrollFrame_GetOffset(scrollFrame)
    local numDisplayed = 15

    FauxScrollFrame_Update(scrollFrame, math.max(numDisplayed + 1, #members), numDisplayed, 22)

    for i = 1, numDisplayed do
        local index = offset + i
        local button = _G["GuildManagerEntry"..i]

        if not button then
            DEFAULT_CHAT_FRAME:AddMessage("Guild Manager ERROR: Button " .. i .. " not found!")
        else
            -- Check if button's text elements are initialized
            if not button.nameText then
                DEFAULT_CHAT_FRAME:AddMessage("Guild Manager ERROR: Button " .. i .. " nameText not initialized!")
                -- Try to initialize manually
                button.nameText = _G["GuildManagerEntry"..i.."Name"]
                button.levelText = _G["GuildManagerEntry"..i.."Level"]
                button.rankText = _G["GuildManagerEntry"..i.."Rank"]
                button.noteText = _G["GuildManagerEntry"..i.."Note"]
                button.officerNoteText = _G["GuildManagerEntry"..i.."OfficerNote"]
            end

            if index <= #members then
                local member = members[index]

                DEFAULT_CHAT_FRAME:AddMessage("Setting button " .. index .. " to member: " .. member.name)

                -- Store the member data on the button for later access
                button.memberData = member

                -- Set name with class color
                local classColor = RAID_CLASS_COLORS[member.classFileName]
                if classColor then
                    -- Construct color string from RGB values (3.3.5a compatible)
                    local colorStr = string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
                    button.nameText:SetText("|cff" .. colorStr .. member.name .. "|r")
                else
                    button.nameText:SetText(member.name)
                end

                -- Set level and class
                button.levelText:SetText(member.level)

                -- Set rank (role)
                button.rankText:SetText(member.rank)

                -- Set public note
                button.noteText:SetText(member.note)

                -- Set officer note (only visible if you have permission)
                button.officerNoteText:SetText(member.officernote)

                -- Set online status indicator
                if member.online then
                    button.nameText:SetAlpha(1.0)
                    button.levelText:SetAlpha(1.0)
                    button.rankText:SetAlpha(1.0)
                    button.noteText:SetAlpha(1.0)
                    button.officerNoteText:SetAlpha(1.0)
                else
                    button.nameText:SetAlpha(0.5)
                    button.levelText:SetAlpha(0.5)
                    button.rankText:SetAlpha(0.5)
                    button.noteText:SetAlpha(0.5)
                    button.officerNoteText:SetAlpha(0.5)
                end

                button:Show()
                DEFAULT_CHAT_FRAME:AddMessage("Showing button " .. index .. " for member: " .. member.name)
            else
                button.memberData = nil
                button:Hide()
                DEFAULT_CHAT_FRAME:AddMessage("Hiding button " .. i .. " (no member)")
            end
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage("Guild Manager: UpdateScrollFrame completed")
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
    DEFAULT_CHAT_FRAME:AddMessage("Guild Manager: Searching for '" .. searchText .. "'")
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
        {name = "Lvl", column = "level", button = GuildManagerFrameHeaderFrameLevelHeader},
        {name = "Rank", column = "rank", button = GuildManagerFrameHeaderFrameRankHeader},
        {name = "Public Note", column = "note", button = GuildManagerFrameHeaderFrameNoteHeader},
        {name = "Officer Note", column = "officernote", button = GuildManagerFrameHeaderFrameOfficerNoteHeader}
    }

    for _, header in ipairs(headers) do
        if header.button then
            header.button:SetText(header.name .. self:GetSortIndicator(header.column))
        end
    end
end

-- Handle entry click
function GuildManager:OnEntryClick(button)
    if not button.memberData then
        return
    end

    selectedMember = button.memberData
    self:ShowEditDialog(selectedMember)
end

-- Show edit dialog
function GuildManager:ShowEditDialog(member)
    if not GuildManagerEditDialog then
        DEFAULT_CHAT_FRAME:AddMessage("Guild Manager ERROR: Edit dialog not found!")
        return
    end

    -- Set member info
    GuildManagerEditDialogNameValue:SetText(member.name)
    GuildManagerEditDialogRankValue:SetText(member.rank)

    -- Set notes in edit boxes (access the EditBox inside the ScrollFrame)
    local publicNoteEdit = GuildManagerEditDialogPublicNoteScrollEdit
    local officerNoteEdit = GuildManagerEditDialogOfficerNoteScrollEdit

    if publicNoteEdit then
        publicNoteEdit:SetText(member.note)
    end

    if officerNoteEdit then
        officerNoteEdit:SetText(member.officernote)
    end

    -- Show the dialog
    GuildManagerEditDialog:Show()
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

    -- Use WoW API to set guild member notes
    -- Note: You need appropriate guild permissions to edit notes
    GuildRosterSetPublicNote(selectedMember.index, publicNote)
    GuildRosterSetOfficerNote(selectedMember.index, officerNote)

    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Guild Manager:|r Updated notes for " .. selectedMember.name)

    -- Hide dialog and refresh
    GuildManagerEditDialog:Hide()
    self:RequestGuildRoster()
end
