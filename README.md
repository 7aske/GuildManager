# Guild Manager - WoW 3.3.5a Addon

A comprehensive guild management addon for World of Warcraft 3.3.5a that provides an enhanced UI for managing guild members with advanced sorting and searching capabilities.

![Guild Manager Screenshot](https://i.imgur.com/CU0kR75.png)

## Features

- **Sortable Columns**: Click on any column header to sort by:
  - Name (alphabetically)
  - Level (numeric)
  - Rank/Role (by rank index)
  - Note (alphabetically)
  - Officer's Note (alphabetically)
  - Class (alphabetically)

- **Real-time Search**: Search guild members by:
  - Name
  - Rank
  - Note
  - Officer's Note
  - Class

- **Visual Indicators**:
  - Class-colored names
  - Online/Offline status (dimmed for offline members)
  - Sort direction indicators (^/v)
  - Scrollable member list

- **Easy Access**: Simple slash commands to open the interface
- **Auto-refresh**: Automatically updates when guild roster changes

## Installation

1. Click the "Code" button above and select "Download ZIP"
2. Extract the ZIP file
3. Rename the extracted folder to `GuildManager` (remove any `-master` or version suffix)
4. Navigate to your WoW installation directory
5. Place the `GuildManager` folder in `World of Warcraft/Interface/AddOns/`
6. Start World of Warcraft
7. At the character selection screen, click "AddOns" to verify it's loaded
8. Log in to a character that is in a guild

## Usage

### Opening the Guild Manager

Use one of these commands in chat:
- `/gman`
- `/guildmanager`

### Sorting Members

Click on any column header to sort by that column:
- Click once to sort ascending
- Click again to sort descending
- The active sort column shows an arrow indicator (▲ or ▼)

### Searching Members

1. Type in the search box at the top of the window
2. The list will automatically filter to show only members matching your search
3. Search works across all fields (name, rank, public note, officer note)
4. Clear the search box to show all members again

### Refreshing the List

Click the "Refresh" button to manually update the guild roster from the server.

### Toggling offline members

Click the "Show Offline Members" button to toggle the visibility of offline guild members.

### Moving the Window

Click and drag anywhere on the window (except buttons) to move it around the screen.

## Notes

- Officer notes are only visible if you have the appropriate guild permissions
- Online members are shown at full brightness, offline members are dimmed
- Member names are colored according to their class
- The addon automatically updates when guild roster changes

## Compatibility

- **Game Version**: World of Warcraft 3.3.5a (WotLK)
- **Interface Version**: 30300

## Troubleshooting

**Addon doesn't show up:**
- Make sure the folder is named exactly `GuildManager`
- Verify all three files are in the folder
- Check that AddOns are enabled at character selection

**Can't see officer notes:**
- This requires guild permissions to view officer notes
- If you don't have permission, this column will be empty

**Roster not updating:**
- Click the Refresh button
- The game server limits how often roster data can be requested

## License

Free to use and modify for personal use.

## Version History

**v1.0.0** (Initial Release)
- Sortable columns (Name, Level, Rank, Note, Officer's Note, Class)
- Real-time search functionality
- Class-colored names
- Online/Offline status indicators
- Scrollable member list (15 visible at once)
- Auto-refresh on roster updates

