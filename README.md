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

- **Settings** — Hours per day/week, sync interval, launch at login, Git identity, repo selection

## Installation

1. Download **Metrik.zip** from the [latest release](../../releases/latest)
2. Unzip and move **Metrik.app** to `/Applications`
3. Before first launch, open Terminal and run:
   ```bash
   xattr -cr /Applications/Metrik.app
   ```
4. Double-click to open

> **Why `xattr`?** Metrik is not notarized with Apple (that requires a $99/year developer account). The `xattr` command removes the macOS quarantine flag so Gatekeeper allows the app to run. You only need to do this once.
>
> **Alternative:** Right-click Metrik.app, choose **Open**, then click **Open** in the dialog.

## Requirements

- **macOS 14.0** or later
- **Xcode 26+** (for building — required for macOS 26 liquid glass APIs)
- **XcodeGen** (`brew install xcodegen`)

## Building

1. Clone the repo and generate the Xcode project:
   ```bash
   git clone <repo-url>
   cd metrik
   xcodegen generate
   ```
2. Open in Xcode, select the **Metrik** scheme, and build (**⌘R**). Or build from the command line:
   ```bash
   xcodebuild -project Metrik.xcodeproj -scheme Metrik -configuration Debug build \
     CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO
   ```

The app will appear in the menu bar. On first launch you’ll go through the setup wizard.

## Releasing

Releases are built locally (Xcode 26 is required for the full liquid glass UI). To create a release:

```bash
# 1. Build
xcodegen generate
xcodebuild -project Metrik.xcodeproj -scheme Metrik -configuration Release \
  -derivedDataPath .build CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual CODE_SIGNING_ALLOWED=YES

# 2. Re-sign with hardened runtime
codesign --force --deep --sign - --options runtime .build/Build/Products/Release/Metrik.app

# 3. Package
cd .build/Build/Products/Release
ditto -c -k --keepParent Metrik.app Metrik.zip
```

Then tag and push — a GitHub Release is created automatically:

```bash
git tag v1.x
git push origin main --tags
```

Upload `Metrik.zip` to the release on GitHub.

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


Data is stored locally with **SwiftData**; no server or account is used.

## Configuration and data

- **Settings** — Open via the gear icon in the dashboard or **⌘,**. Configure hours, sync interval, launch at login, goal, and working days. Account/repo settings let you change tracked repos and Git identity.
- **Reset** — To start over (clear all config and commit data), use the reset option in Settings (e.g. Debug or a dedicated reset control if present). This removes `LocalGitConfig`, `MergedCommit`, `TrackedRepo`, and `DailySummary` from the store.

## License

See the repository for license information.
