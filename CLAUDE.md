# ORGA Addon Development Notes

## Overview
ORGA is a World of Warcraft Classic addon developed for the "OnlyRejects" guild. It consists of several modules:
- ORGA (main window) - Core functionality and UI framework
- ORGA_Deathlog - Death tracking system
- ORGA_Events - Event planning and management with timezone support
- ORGA_ORGS (guild bank system) - Guild bank inventory management
- ORGA_REJECTS - Additional guild management features

**Current Version:** 1.0.10

## Recent Changes

### Events Module Implementation (March 2025)
- Implemented full event management system with timezone support
- Added role-based permissions (OnlyOfficer and Warchief ranks can manage events)
- Created event creation form with date/time picker
- Implemented countdown timer showing days, hours, minutes until event
- Added automatic timezone conversion for all guild members
- Built responsive UI with scrollable event list
- Implemented edit and delete functionality for event managers
- Added /orgaevents command to quickly access the Events tab

### Main ORGA Addon Improvements (March 2025)
- Added version control system (v1.0.1) for better tracking and updates
- Implemented guild membership verification
- Added guild invite system for non-guild members
- Created automatic guild invite responses for members
- Fixed window resizing and position saving
- Added improved debugging tools with copy functionality
- Implemented robust error handling
- Added comprehensive slash commands for all functionality

### ORGS Module Code Refactoring (March 2025)
- Modularized the ORGA_ORGS addon for better maintainability
- Split monolithic ORGA_ORGS.lua (1000+ lines) into four focused modules:
  - ORGA_ORGS.lua - Core functionality
  - ORGA_ORGS_Inventory.lua - Inventory scanning
  - ORGA_ORGS_Cart.lua - Shopping cart
  - ORGA_ORGS_UI.lua - User interface
- Detailed documentation in ORGA_ORGS/ORGA_ORGS_Refactoring.md

### ORGS Module Improvements (March 2025)

#### Bank Scanning System
- Fixed item duplication bug in inventory scanning
- Added Bagnon/Bagon compatibility for bank scanning
- Implemented reliable bag detection by item ID and slot count
- Fixed GetItemInfo nil errors by using direct item ID comparison

#### UI Improvements
- Made window resizable with proper sizing constraints
- Added window position/size saving
- Implemented responsive item grid that adjusts to window size
- Added two-column layout for gold displays
- Created separate fixed headers and scrollable item content
- Added visual separators between sections
- Suppressed message spam during window resizing

#### Shopping Cart System
- Implemented shopping cart for requesting items
- Added item request functionality for players
- Created bank alt management interface

### Documentation Updates
- Created comprehensive README.md for GitHub repository
- Updated CLAUDE.md with all feature changes and improvements
- Added detailed slash command documentation

## Deployment

### Local Development
Use the update_addon.sh script to deploy changes to local WoW directory for testing:
```
./update_addon.sh
```

### Release Deployment
The addon is configured for automatic packaging and deployment to CurseForge:

1. Update version numbers in all TOC files
2. Tag the release in git: `git tag v1.0.2`
3. Push the tag to GitHub: `git push origin v1.0.2`

The GitHub Action will automatically:
- Package the addon
- Create a GitHub Release
- Upload to CurseForge

### CurseForge Configuration
- `.pkgmeta` - Defines packaging structure
- `.github/workflows/release.yml` - GitHub Action for automatic releases
- All TOC files contain CurseForge metadata

## Useful Commands
- `/orgasave` - Manually save inventory data
- `/orgsverbose` - Toggle verbose logging

## Known Issues
- Sometimes need to close and reopen bank to properly scan all items
- Bagnon compatibility may require multiple attempts to scan bank correctly
- Guild membership detection might need guild info refresh on login
- WHO results may require multiple searches in some WoW versions

## Slash Commands
- `/orga` - Toggle the main addon window
- `/orgabutton show` - Show minimap button
- `/orgabutton hide` - Hide minimap button
- `/orgadebug` - Show debug information window
- `/orgaversion` - Show addon version information
- `/orgahelp` - Show full command list
- `/orgasave` - Manually save inventory data (ORGS module)
- `/orgsverbose` - Toggle verbose logging (ORGS module)
- `/orgaevents` - Open the Events tab
- `/orgaevents debug` - Toggle Events module debug mode and show rank information
- `/orgaevents forcepermission` - Testing command to override rank permissions

## Bag Item IDs for Reference
- Linen Bag: 4238
- Wool Bag: 4240
- Silk Bag: 4241
- Mageweave Bag: 10050
- Runecloth Bag: 14046
- Traveler's Backpack: 4500