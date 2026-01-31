# Budget Splitter — iOS App

A SwiftUI iOS app for splitting trip expenses among group members. Designed for the Japan Trip 2026.

## Features

- **Overview (Dashboard)** — Stats (total expenses, total spent, per person, members), Quick Actions, Spending by Category
- **Add Expense** — Form with description, amount, category, currency, paid-by, date, equal split among selected members
- **Expenses List** — View all recorded expenses with metadata
- **Members** — Add/remove members, Reset All Data
- **Summary** — Per-member totals and by-category breakdown (sheet from Quick Action)

## Setup (Xcode on Mac)

1. Open Xcode and create a new project: **File → New → Project**
2. Choose **iOS → App**, name it `BudgetSplitter`
3. Set Interface to **SwiftUI**, Language **Swift**, minimum deployment **iOS 17**
4. Delete the default `ContentView.swift` if it was created
5. Add the project files to the target:
   - Drag `BudgetSplitterApp.swift`, `ContentView.swift` into the project
   - Drag the `Models` folder (Expense, Member, BudgetDataStore)
   - Drag the `Views` folder (OverviewView, AddExpenseView, ExpensesListView, MembersView, SummarySheetView)
6. Ensure all files are added to the **BudgetSplitter** target
7. Build and run (⌘R)

## Design

Based on `ios-budget-splitter-mockups.html` — dark iOS-style UI with:
- Tab bar: Overview, Add, Expenses, Members
- Navigation bar: 💰 Budget Splitter, 🌐 EN
- Stat cards: blue, green, orange, purple gradients
- Quick Actions for navigation
- Category progress bars
- Member chips and summary breakdowns

## Data

- Members and expenses persist in `UserDefaults`
- Default members are seeded on first launch
- Reset All Data clears members and expenses
