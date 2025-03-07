# Fix CurseForge Packaging Structure

## Description
This PR fixes issues with the CurseForge installation where sub-addons were not being properly recognized by the game after installation. The main changes:

1. Modified `.pkgmeta` configuration to package addons at the root level instead of nested under ORGA-Suite
2. Removed ORGA-Suite.toc (no longer needed with the new packaging approach)
3. Updated all addon versions to 1.0.14
4. Consolidated SavedVariables references in the core ORGA.toc file

## Testing Steps
1. Install the addon via CurseForge
2. Verify that all sub-addons (ORGA, ORGA_Deathlog, ORGA_Events, ORGA_ORGS, ORGA_REJECTS) are recognized by the game
3. Check that all functionality works as expected

## Technical Details
The issue was caused by the previous packaging structure, which placed all addons under an ORGA-Suite folder. With the new configuration, each addon will be installed directly in the AddOns folder, matching the expected structure for dependencies to work correctly.

## Release Process
1. Merge this PR
2. Tag the release: `git tag v1.0.14`
3. Push the tag: `git push origin v1.0.14`
4. GitHub Action will automatically create a release and package the addon for CurseForge