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

1. Open Xcode → **File → New → Project** → iOS App, name `BudgetSplitter`
2. Interface: **SwiftUI**, Language: **Swift**, iOS 17+
3. Add all source files:
   - `BudgetSplitterApp.swift`, `ContentView.swift`
   - `Config/AppConfig.swift`
   - `Models/` (Expense, Member, BudgetDataStore)
   - `Views/` (OverviewView, AddExpenseView, ExpensesListView, MembersView, SummarySheetView)
   - `Views/Auth/` (LoginView, RegisterView, RemoteModeRootView)
   - `Services/AuthService.swift`
4. Build and run (⌘R)

**VPS mode**: Add `USE_REMOTE_API=1` and `API_BASE_URL` to Build Settings → User-Defined.

## Server (API)

Server is in **budget_splitter_web** (sibling folder). Runs on **port 3012**, database **budget_splitter**.

```bash
cd ../budget_splitter_web
npm install && cp .env.example .env && npm start
pm2 start ecosystem.config.js  # or --env local / --env vps
```

## Design

Based on `ios-budget-splitter-mockups.html` — dark iOS UI, stat cards, Quick Actions.
