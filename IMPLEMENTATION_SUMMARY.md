# Implementation Summary

This document summarizes the features implemented for the Budget Splitter (Exsplitter) iOS app.

---

## 1. Expense detail – Edit expense

**Goal:** Allow correcting an expense (currency, amounts, or members) after it was added.

- **BudgetDataStore**
  - `updateExpense(_ expense: Expense)` – Replaces an expense by id, clears settled state for participants, saves.
- **AddExpenseView**
  - Optional `existingExpense: Expense?` for edit mode.
  - `prefillFromExpense(_ e: Expense)` – Prefills description, amount, category, currency, paid-by, date, split members, split mode (treat everyone / split with others), split type (equal / custom), and payer-not-in-split option.
  - Submit: if `existingExpense != nil`, builds expense with same `id` and `eventId`, calls `updateExpense`, shows “Updated” toast, then dismisses; otherwise adds as new and shows “Successfully added”.
  - Navigation and form title show **“Edit expense”** when editing (localized).
- **ExpenseDetailView**
  - **Edit** toolbar button opens a sheet with `AddExpenseView(existingExpense: currentExpense)`.
  - `currentExpense` is resolved from `dataStore.expenses` by id so the detail updates after edit without leaving the screen.
  - On Edit, the expense’s event is selected so the form has the correct members.
- **L10n**
  - `addExpense.editTitle`, `addExpense.successfullyUpdated`.

---

## 2. Remove member – Confirmation

**Goal:** Avoid accidental removal; show a confirmation before removing a member.

- **MembersView**
  - Trash button sets `memberToRemove = member` instead of removing immediately.
  - **Alert:** title “Remove member?”, message “Remove [name] from the group? Expenses that include this member will be updated.” (localized).
  - **Cancel** – Dismisses and clears `memberToRemove`.
  - **Remove (destructive)** – Calls `dataStore.removeMember`, then clears state; if that member was the first (host), the “Add new host” sheet is shown as before.
- **L10n**
  - `members.removeConfirmTitle`, `members.removeConfirmMessage`.

---

## 3. Member leave history (left the group + date)

**Goal:** Record when a member leaves and show it in history.

- **Model**
  - `FormerMember`: `id`, `name`, `joinedAt?`, `leftAt` (Codable, Identifiable).
  - `Event.formerMembers: [FormerMember]` – Persisted with the event.
- **BudgetDataStore**
  - On `removeMember` (event context): before removing from `event.members`, appends a `FormerMember` with `leftAt: Date()` to `event.formerMembers`.
  - `formerMembers(for eventId: String?) -> [FormerMember]` – Returns that event’s former members (or `[]` when no event).
- **LocalStorage**
  - Migration adds `former_members` column (TEXT/JSON); load decodes it into `Event.formerMembers`; save writes it in the events INSERT.
- **MembersView – Member History**
  - When expanded: current members show “joined on [date]”; former members show “left the group on [date]” (sorted by leave date, newest first), with slightly muted styling.
- **L10n**
  - `members.leftOn`: “left the group on %@” (EN/ZH/JA).

---

## 4. Invite removed person back

**Goal:** Re-add a member who was removed, without losing history.

- **BudgetDataStore**
  - `addFormerMemberBack(_ former: FormerMember, eventId: String)` – Ensures the event exists and the person is not already in `event.members`; appends `Member(id: former.id, name: former.name, joinedAt: Date())` to the event; adds id to `selectedMemberIds`; does **not** remove the leave record from `formerMembers`.
- **MembersView – Member History**
  - For each former member: **“Invite back”** button only when their id is **not** in `currentMembers` (so no button if they were already re-added).
  - Tapping it calls `addFormerMemberBack(former, eventId:)`; they appear again in the main member list with a new join date; their “left on [date]” row remains in history.
- **L10n**
  - `members.inviteBack`: “Invite back” / “重新邀请” / “再度招待”.

---

## 5. Payment received – Edit and Remove

**Goal:** Correct or delete a recorded payment if the number (or other details) was entered incorrectly.

- **BudgetDataStore**
  - `removeSettlementPayment(id: String)` – Removes the payment by id and saves.
  - `updateSettlementPayment(_ payment: SettlementPayment)` – Replaces the payment with the same id and saves.
- **SettleUpDebtorDetailSheet – “Payments received”**
  - Each payment row has **Edit** and **Remove**:
    - **Edit** – Presents a sheet to edit: amount applied, amount received, note, change given back, amount treated by you. Save updates via `updateSettlementPayment` and closes; Cancel closes without saving.
    - **Remove** – Presents an alert: “Remove this payment?” and message that the record will be removed and the amount will count as unpaid again. Confirm calls `removeSettlementPayment(id:)` and dismisses.
- **EditSettlementPaymentSheet**
  - Form fields: Amount (applied), Amount received, Note, Change given back, Treated by you (all pre-filled from the selected payment). Save builds an updated `SettlementPayment` (same id, date, `paymentForExpenseIds`) and calls the update callback.
- **L10n**
  - `settle.editPayment`, `settle.removePayment`, `settle.removePaymentConfirmTitle`, `settle.removePaymentConfirmMessage`.

---

## Files touched (overview)

| Area              | Files |
|-------------------|------|
| Expense edit      | `BudgetDataStore.swift`, `AddExpenseView.swift`, `ExpenseDetailView.swift`, `L10n.swift` |
| Member remove     | `MembersView.swift`, `L10n.swift` |
| Leave history     | `Member.swift`, `Event.swift`, `BudgetDataStore.swift`, `LocalStorage.swift`, `MembersView.swift`, `L10n.swift` |
| Invite back       | `BudgetDataStore.swift`, `MembersView.swift`, `L10n.swift` |
| Payment edit/remove | `BudgetDataStore.swift`, `SettleUpView.swift`, `L10n.swift` |

All of the above use the existing persistence (LocalStorage / BudgetDataStore `save()`) so data is stored as before; new fields (e.g. `formerMembers`) are migrated where needed.
