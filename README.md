# ORGA (Only Rejects Guild Addon)

![ORGA Logo](ORGA/Textures/background.tga)

ORGA is a comprehensive guild management addon for World of Warcraft Classic designed specifically for the "OnlyRejects" guild. It provides guild members with tools for organization, guild bank management, event planning, and more.

**Version:** 1.0.14

## Features

ORGA consists of several integrated modules:

### Core Module (ORGA)
- Customizable main interface with resizable window
- Tab-based navigation system for all modules
- Minimap button for quick access
- Guild membership verification
- Automatic guild invite system for new members
- Comprehensive slash commands

### Guild Bank System (ORGA_ORGS)
- Inventory scanning and tracking for bank alts
- Complete guild bank item management
- Shopping cart system for requesting items
- Display of all available items with search and filter options
- Bank alt management interface

### Death Log (ORGA_DeathLog)
- Tracks guild member deaths
- Historical death data

### Event System (ORGA_Events)
- Guild event planning and management

### R.E.J.E.C.T.S. System (ORGA_REJECTS)
- Special features for guild management

## Installation

### Method 1: CurseForge App (Recommended)
1. Open the CurseForge App
2. Search for "ORGA" or "Only Rejects Guild Addon"
3. Click "Install"
4. Launch World of Warcraft

### Method 2: Manual Installation
1. Download the latest release from [CurseForge](https://www.curseforge.com/wow/addons/orga) or [GitHub Releases](https://github.com/Lyderian/ORGA/releases)
2. Extract the contents to your World of Warcraft `Interface/AddOns` directory
3. Ensure all folders are correctly named:
   - ORGA
   - ORGA_Deathlog
   - ORGA_Events
   - ORGA_ORGS
   - ORGA_REJECTS
4. Restart World of Warcraft if it's running

## Usage

### Slash Commands

- `/orga` - Toggle the main addon window
- `/orgabutton show` - Show minimap button
- `/orgabutton hide` - Hide minimap button
- `/orgaversion` - Show addon version information
- `/orgadebug` - Show debug information window
- `/orgahelp` - Show full command list
- `/orgasave` - Manually save inventory data (ORGS module)
- `/orgsverbose` - Toggle verbose logging (ORGS module)

### For Guild Members

1. Open the addon interface by clicking the minimap button or typing `/orga`
2. Navigate between modules using the tabs at the top of the window
3. Use the ORGS tab to view the guild bank contents and request items
4. Check the Events tab for upcoming guild activities
5. View the Death Log to see recent player deaths
6. Drag the window by the top bar to reposition, or resize from the bottom-right corner

### For Bank Alts

1. Bank alts have access to additional features to manage the guild bank
2. When a bank is opened, inventory is automatically scanned
3. Special requests tab shows all pending item requests from guild members
4. Use `/orgasave` to manually trigger inventory data saves

### For Non-Guild Members

1. The addon provides a streamlined interface for requesting guild invites
2. Click the "Search for Members" button to find online guild members
3. Click "Request Invite" next to any member's name to send them a whisper
4. Guild members with the addon will automatically send invites when they receive these requests

## Features for Guild Members

- View all items stored in the guild bank
- Request items through the shopping cart system
- See upcoming guild events
- Track guild member deaths
- Access guild management features
- Automatic guild invite responses

## Bank Alt Features

- Automatic inventory scanning
- Manual inventory updates through slash commands
- Review and process item requests from guild members
- Track gold amounts across bank characters

## Developer Information

The addon is organized into several modules:

- **ORGA**: Core functionality and UI framework
- **ORGA_ORGS**: Guild bank system (Only Rejects Guild Storage)
- **ORGA_DeathLog**: Death tracking system
- **ORGA_Events**: Event planning and management
- **ORGA_REJECTS**: Additional guild management features

### Development & Contribution

1. Clone the repository: `git clone https://github.com/Lyderian/ORGA.git`
2. Make your changes following the existing code style
3. Test your changes in-game
4. Submit a pull request with a detailed description of your changes

### Releasing New Versions

This addon uses automated packaging through GitHub Actions and CurseForge:

1. Update version numbers in all TOC files
2. Tag the release in git: `git tag v1.0.9`
3. Push the tag to GitHub: `git push origin v1.0.9`
4. The GitHub Action will automatically:
   - Package the addon
   - Create a GitHub Release
   - Upload to CurseForge

## Support & Feedback

For support, feedback, or to report bugs, please create an issue in the GitHub repository.

## License

This addon is designed specifically for the "OnlyRejects" guild and is licensed under [All Rights Reserved] for controlled distribution. While the code is public on GitHub for educational purposes, it is not permitted for redistribution or use by other guilds without explicit permission.

## Acknowledgements

Developed by Lyderian for the OnlyRejects guild.

## Changelog

### Version 1.0.14
- Fixed CurseForge packaging structure to ensure sub-addons are properly recognized by the game
- Modified packaging configuration to place addons at the root level rather than nested
- Ensured consistent versioning across all addon modules
- Consolidated all SavedVariables references in the core addon

### Version 1.0.9
- Updated interface version to support WoW Classic 1.15.6
- Changed all purple text to white for better readability
- Fixed CurseForge packaging structure
- Improved addon distribution system

### Version 1.0.8-1.0.7
- Initial CurseForge integration
- Set up automated GitHub releases
- Created packaging configuration

### Version 1.0.1
- Added guild invite request system for non-guild members
- Added automatic guild invite response for members
- Fixed window resizing and position saving
- Added version tracking and update checks
- Improved debug tools and error handling
- Added bank alt detection and special interfaces

### Version 1.0.0
- Initial release with basic functionality
- Created tab system for module navigation
- Implemented guild bank inventory system
- Added minimap button for quick access