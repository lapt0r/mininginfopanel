# Mining Info Panel - Patch Notes


## [Unreleased] - Release Candidate

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
