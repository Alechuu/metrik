# Metrik

A macOS menu bar app that tracks your coding activity from local Git repositories. See lines added, lines deleted, and commit counts for today, this week, or this month—with optional goals and a breakdown by repo.

## Features

- **Menu bar presence** — Live in the menu bar; click to open a compact dashboard
- **Local Git only** — Scans and reads commits from Git repos on your machine (no cloud, no account)
- **Time ranges** — Switch between Today, This Week, and This Month
- **Coding goals** — Set a goal (e.g. 500 lines per week or N lines per hour) and see progress
- **Repo breakdown** — Horizontal bar chart of contributions per repository
- **Recent activity** — List of recent commits with details
- **Working days** — Configure which weekdays count (e.g. Mon–Fri) so weekends show an “off day” view
- **Widget** — macOS widget extension (small and medium) for a quick glance
- **Settings** — Hours per day/week, sync interval, launch at login, Git identity, repo selection

## Requirements

- **macOS 14.0** or later
- **Xcode** (for building)
- **Swift 5** (project uses SwiftData, SwiftUI, `@Observable`)

## Building

1. Clone the repo and open the project in Xcode:
   ```bash
   git clone <repo-url>
   cd metrik
   open Metrik.xcodeproj
   ```
2. Select the **Metrik** scheme and a **My Mac** destination.
3. Build and run (**⌘R**).

The app will appear in the menu bar. On first launch you’ll go through the setup wizard.

## Setup (first run)

The wizard has four steps:

1. **Root directory** — Choose a folder that contains (or will contain) your Git repos. Metrik scans up to 3 levels deep for `.git` directories.
2. **Select repos** — Pick which of the found repos to track.
3. **Identity** — Confirm or enter the Git name/email used for attributing commits.
4. **Coding goal** (optional) — Set a target (e.g. lines per week or per hour). You can change or clear this later in Settings.

After setup, the app syncs commits from the selected repos on an interval (default 15 minutes, configurable in Settings).

## Project structure

- **Metrik** — Main app: menu bar (status item), popover, dashboard, setup wizard, settings windows.
- **MetrikShared** — Shared logic: `LocalGitService` (repo scan, commit reading), `MetricsCalculator`, SwiftData models (`UserSettings`, `MergedCommit`, `TrackedRepo`, `LocalGitConfig`, `DailySummary`), `SyncService`, `PersistenceController`.
- **MetrikWidgetExtension** — Widget extension (small/medium) and timeline provider.

Data is stored locally with **SwiftData**; no server or account is used.

## Configuration and data

- **Settings** — Open via the gear icon in the dashboard or **⌘,**. Configure hours, sync interval, launch at login, goal, and working days. Account/repo settings let you change tracked repos and Git identity.
- **Reset** — To start over (clear all config and commit data), use the reset option in Settings (e.g. Debug or a dedicated reset control if present). This removes `LocalGitConfig`, `MergedCommit`, `TrackedRepo`, and `DailySummary` from the store.

## License

See the repository for license information.
