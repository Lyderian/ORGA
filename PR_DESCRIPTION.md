# Add CurseForge Packaging Configuration

## Description
This pull request configures the ORGA addon for automatic packaging and distribution through CurseForge. It includes all necessary configuration files and updates to TOC files.

## Changes
- Created `.pkgmeta` file for CurseForge packaging
- Set up GitHub Action workflow for automated releases
- Updated all TOC files with proper metadata and version information
- Added CurseForge-specific metadata to main ORGA.toc file
- Created `.gitattributes` for proper line ending control
- Added `.gitignore` for repository cleanliness
- Updated README.md with CurseForge installation instructions
- Added development and release documentation
- Updated CLAUDE.md with CurseForge deployment information

## How to test
1. Merge this PR
2. Create a new tag: `git tag v1.0.2`
3. Push the tag: `git push origin v1.0.2`
4. GitHub Action should automatically create a release and package the addon

## Release Process After Merge
For future releases:
1. Update version numbers in all TOC files
2. Tag the release with `git tag v1.0.x`
3. Push the tag with `git push origin v1.0.x`

The GitHub Action will automatically package the addon and deploy it to CurseForge (once API keys are set in repository secrets).