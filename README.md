# Budget Splitter — iOS App

A SwiftUI iOS app for splitting trip expenses. Supports **local** (device storage) and **VPS** (cloud sync with login) modes.

## Features

- **Overview** — Stats, Quick Actions, Spending by Category
- **Add Expense** — Form with equal split among members
- **Expenses List** — View all recorded expenses
- **Members** — Add/remove, Reset All Data
- **Summary** — Per-member totals, by-category breakdown
- **Settings** — Mode indicator, Logout (VPS)

## Modes

| Mode | Login | Storage | Config |
|------|-------|---------|--------|
| **Local** | No | UserDefaults (device) | `USE_REMOTE_API=0` (default) |
| **VPS** | Yes | PostgreSQL on server | `USE_REMOTE_API=1`, `API_BASE_URL` |

See [DESIGN_MODES.md](DESIGN_MODES.md) for details.

## Setup (Xcode on Mac)

1. Open `Exsplitter/Exsplitter.xcodeproj` in Xcode
2. Build and run (⌘R)

Source code is in `Exsplitter/Exsplitter/` (BudgetSplitterApp, Config, Models, Services, Views).

## Server (API)

Server is in **budget_splitter_web** (sibling folder). Runs on **port 3012**, database **budget_splitter**.

```bash
cd ../budget_splitter_web
npm install && cp .env.example .env && npm start
pm2 start ecosystem.config.js  # or --env local / --env vps
```

## Design

Based on `ios-budget-splitter-mockups.html` — dark iOS UI, stat cards, Quick Actions.
