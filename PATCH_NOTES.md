# Mining Info Panel - Patch Notes



## [1.2.0] - 2026-01-04

### [FEATURE]
- Implement profession quality aggregation system
## [1.1.2] - 2026-01-04

### [FIX]
- Fix The War Within mining detection
## [Unreleased] - Release Candidate

### [FIX]
- Fixed The War Within mining detection by adding missing spell ID (423341)
- Corrected ore item IDs for Bismuth, Ironclaw, and Aqirite with all quality tiers
- Enhanced mining item detection to check both item family and ore lookup table
- Added fallback detection using recent mining cast timestamps
- Preload item info for TWW ores to prevent nil returns from GetItemInfo

### [ENHANCEMENT]
- Database version updated to v3 with automatic migration
- Clear TWW zone node data on migration to ensure proper ore tracking
- Profession quality aggregation: ore counts sum quantities across quality tiers (1/2/3)
- Profession quality color coding: White (Q1), Green (Q2), Blue (Q3)
- Quality breakdown tooltip: hover over ores to see detailed quality distribution
- Fixed quantity vs quality counting issue - now tracks actual ore amounts

## [1.1.1] - 2026-01-03

### [FIX]
- Display filtering to show only looted items

## [1.1.0] - 2026-01-03

### [BREAKING]
- Statistics now track by node type instead of ore quantities
- Percentages represent what % of nodes mined yielded each node type
- Database version updated to v2 with automatic migration
- Old node tracking data reset for improved accuracy

### [FEATURE]
- Added comprehensive ore lookup table for accurate node identification
- Supports all expansion ores: TWW, Dragonflight, Shadowlands, and Legacy
- Node types identified by ore item IDs instead of loot order
- Early exit logic: nodes only contain one ore type for efficiency

### [ENHANCEMENT]
- Mixed display shows both ore types (node-based) and non-ore items (quantity-based)
- Added separate "Nodes" and "Count" columns for comprehensive tracking
- Ore types show node counts and percentages (% of nodes that were this ore type)
- Non-ore items show containment percentages (% of nodes that contained this item)
- Updated "Yield/hr" calculation based on session timestamps instead of rolling window
- Node types stored by item ID for proper localization support
- Improved debug logging shows identified node types
- Items sorted with ore types first, then non-ore items by total count

## [1.0.1] - 2026-01-02

### [FEATURE]
- Added GitHub Actions workflows for automated CurseForge releases
- Added continuous integration with linting and security checks

## [1.0.0] - 2025-01-02

### [FEATURE]
- Initial release of Mining Info Panel
- Tracks mining yields by zone with session vs all-time comparison
- Color-coded percentages: green (above average), red (below average), white (normal)
- Automatic stone/gem categorization and percentage tracking
- Skill-based mining statistics tracking in background
- Configuration system with yield message and debug logging toggles
- Support for skill view mode to analyze yields by mining skill ranges
- Real-time yield logging with current mining skill display
- Mining rate tracking with nodes/hour projection based on 5-minute rolling window
- Displays real-time mining rate at bottom of panel showing projected nodes per hour
- Added mine time tracking with mean and median statistics
- Tracks time from mining cast to loot window for performance analysis
- Projected time-to-mine for session ores based on historical data (95% confidence range)
- Actual time-to-mine for session ores (from last mine or beginning of session)
- Draggable minimap button with mining pick icon
- Auto open/close functionality - panel opens on mining start, closes on combat start
