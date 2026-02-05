# Plan: Local DB + Cloud Sync (Read/Write)

This document is the **plan and suggestion** before implementation. It covers:
1. Local storage (SQLite instead of UserDefaults)
2. Cloud sync: upload local data when switching to cloud
3. Cloud mode: read/write from API after connected

API reference: `C:\Users\User\Desktop\Website\budget_splitter_web` (API.md, routes/vps.js, routes/local.js, database/schema.sql).

---

## 1. Current State Summary

| Area | Current | Gap |
|------|---------|-----|
| **iOS local** | UserDefaults (JSON blobs) | No SQLite; no “trips” / groups in storage |
| **iOS cloud** | Same UserDefaults; no API calls for data | No upload on switch; no read/write from server |
| **Backend VPS** | GET groups, GET members, GET expenses, POST/DELETE expenses, PATCH split payment | **No POST /api/groups**, **no way to add members to a group** |

So we need both **backend additions** and **iOS changes**.

---

## 2. Backend Gaps (budget_splitter_web)

The VPS API currently has:
- `GET /api/groups` – list groups owned by user
- `GET /api/groups/:groupId/members` – list members (requires user to already be in `group_members`)
- `GET /api/groups/:groupId/expenses` – list expenses
- `POST /api/expenses` – add expense (requires `groupId` and user to be in group)
- `DELETE /api/expenses/:expenseId`, `PATCH /api/expense-splits/:splitId/payment`, etc.

**Missing for “create group and sync local data”:**
- **POST /api/groups** – create a new trip group (name, optional description). Insert into `trip_groups`, insert owner into `group_members`, return `groupId`.
- **POST /api/groups/:groupId/members** – add a “trip member” (name only). Insert into `members` (group_id, name). Optionally ensure current user is in `group_members` (already done when they created the group).

**Suggested backend work (in budget_splitter_web):**
1. Add **POST /api/groups**  
   - Body: `{ "name": "Tokyo Trip", "description": "optional" }`  
   - Create row in `trip_groups` (owner_id = req.user.id), create row in `group_members` (owner), return `{ group: { id, name, ... } }`.
2. Add **POST /api/groups/:groupId/members**  
   - Body: `{ "name": "Alex" }`  
   - Check user is in `group_members` for this group; insert into `members` (group_id, name); return `{ member: { id, groupId, name, createdAt } }`.
3. (Optional) **POST /api/groups/from-local** – single endpoint that accepts `{ name, members: [{ name }], expenses: [...] }`, creates group + members + expenses in one go. Reduces round-trips from the app when “sync local to cloud”.

Implementing (1) and (2) is enough for the iOS app to sync step-by-step (create group → add members → add expenses). (3) is a convenience.

---

## 3. iOS: Local Storage (SQLite)

**Goal:** Replace UserDefaults with a local SQLite DB for the “current trip” data (members, expenses, settlement-related state).

**Options:**
- **SwiftData (iOS 17+)** – Modern, but minimum version may be too high for you.
- **SQLite via SQLite.swift or raw sqlite3** – Works on all current iOS versions, full control.

**Suggested approach: SQLite**

- **Schema (mirror current model):**
  - One “current trip” or “default group” for local mode (single group like the server’s local mode).
  - Tables: `local_group` (id, name), `members` (id, name, created_at), `expenses` (id, description, amount, currency, category, paid_by_member_id, expense_date, created_at), `expense_splits` (id, expense_id, member_id, amount).
  - Optional: `selected_member_ids`, `settled_member_ids`, `settlement_payments`, `paid_expense_marks` – either in SQLite or keep in UserDefaults for simplicity in v1.

- **Where to put DB:**  
  App Support directory, e.g. `.../Application Support/budget_splitter_local.db`.

- **Migration:**  
  On first launch after update: if UserDefaults keys (e.g. `BudgetSplitter_members`) exist, **migrate** them into SQLite (create default group, insert members, insert expenses/splits from decoded JSON), then remove or mark migrated so we don’t run again.

- **BudgetDataStore changes:**  
  - Add a **LocalDB** (or similar) type that wraps SQLite: open DB, run migrations, expose methods like `loadMembers()`, `saveMember()`, `loadExpenses()`, `saveExpense()`, etc.
  - **BudgetDataStore** in local mode: in `load()`, read from LocalDB instead of UserDefaults; in `save()`, write to LocalDB instead of UserDefaults. Keep the same in-memory shape (`[Member]`, `[Expense]`, etc.) so the rest of the app stays unchanged.

**Scope:**  
- One SQLite file for “local mode” only.  
- Cloud mode will use **server as source of truth** (with optional local cache later). So local DB is used only when `AppModeStore.useRemoteAPI == false`.

---

## 4. iOS: Cloud Sync (Upload Local Data When Switching to Cloud)

**Flow when user taps “Switch to Cloud” and then logs in:**

1. User is in **local** mode with data in SQLite (and/or in-memory BudgetDataStore that was loaded from SQLite).
2. User switches to cloud (Settings → Switch to Cloud) → show Login.
3. After **login**:
   - If we have **local data** (current trip with members/expenses), offer **“Upload this trip to cloud”** (or do it automatically).
   - Steps:
     - **POST /api/groups** with name (e.g. “My Trip” or user-defined) → get `groupId`.
     - For each member: **POST /api/groups/:groupId/members** with `{ name }` → get server `memberId`. Build mapping: localMemberId → serverMemberId.
     - For each expense: map `paidByMemberId` and each split’s member to server ids; **POST /api/expenses** with `groupId`, `expenseDate` (YYYY-MM-DD), `splits: [{ memberId, amount }]`.
   - Store `groupId` (and optionally `groupName`) in UserDefaults or Keychain for “current cloud group” for this user.
   - Load that group’s data from server (see below) and show it in the app.

**Edge cases:**
- User has no local data (empty trip) → don’t upload; just **GET /api/groups** and pick first group or show “Create a trip” in cloud.
- User already has cloud groups → after login, show list of groups or pick “current” group; optionally still offer “Import from this device” to create a *new* group from local data.

**Implementation place:**  
- New **CloudSyncService** (or extend a **SyncService**): methods like `uploadLocalToCloud(localMembers, localExpenses, groupName:) async throws -> String` (returns groupId). Uses AuthService for token, AppConfig.apiBaseURL for base URL. Call this after successful login when we detect local data and user chose “sync to cloud”.

---

## 5. iOS: Cloud Mode – Read/Write from API

**Goal:** When in cloud mode and user is authenticated, **read** data from the server and **write** changes (add/delete expense, mark paid) via the API. Optionally cache in memory only (no local SQLite for cloud in v1).

**Current group:**  
- After login (and optionally after “upload local”), we have a **current groupId** (saved when we created/selected a group). Store it e.g. in UserDefaults key `BudgetSplitter_currentGroupId` (or in a small “CloudState” store).

**Read:**
- On entering cloud main UI (or on login):  
  - **GET /api/groups** to list groups; if we have a stored `currentGroupId`, use it; otherwise pick first or show picker.  
  - **GET /api/groups/:groupId/members** → map to `[Member]` (id, name).  
  - **GET /api/groups/:groupId/expenses** → map to app’s `[Expense]` (id, description, amount, category, currency, paidByMemberId, date, splits; server returns `expenseDate`, `splits: [{ id, memberId, amount, isPaid }]`). Map `isPaid` into app’s `paidExpenseMarks` or equivalent.
- Populate **BudgetDataStore** (or a cloud-specific store) with these so existing UI (Overview, Expenses, Settle up, Members) keeps working.

**Write:**
- **Add expense:**  
  - Use **POST /api/expenses** with `groupId`, `paidByMemberId`, `expenseDate` (formatted YYYY-MM-DD), `splits: [{ memberId, amount }]`.  
  - On success, either append the new expense (with server-returned id) to local state or refetch expenses.
- **Delete expense:**  
  - **DELETE /api/expenses/:expenseId**. Then update local state or refetch.
- **Mark split paid/unpaid:**  
  - **PATCH /api/expense-splits/:splitId/payment** with `{ isPaid: true/false }`. Then update local state or refetch.

**Mapping details:**
- Server expense: `expenseDate` (string YYYY-MM-DD), `splits: [{ id, memberId, amount, isPaid }]`.  
- App Expense: `date` (Date), `splits: [String: Double]`, `splitMemberIds: [String]`.  
- Convert when decoding API response: parse `expenseDate` → Date; build `splits` and `splitMemberIds` from `splits` array.  
- `paidExpenseMarks` in the app can be derived from splits where `isPaid == true` (debtor = split.memberId, creditor = paidByMemberId, expenseId = expense.id).

**Who does the work:**  
- A **CloudDataService** (or **APIDataService**): methods `fetchGroups()`, `fetchMembers(groupId:)`, `fetchExpenses(groupId:)`, `createExpense(groupId:...)`, `deleteExpense(expenseId:)`, `setSplitPaid(splitId:isPaid:)`. All use `AuthService.shared.getToken()` and return app-domain types (Member, Expense) or throw.  
- **BudgetDataStore** in cloud mode can either:  
  - Be fed by CloudDataService (load from API on appear, then call API on every add/delete/mark paid), or  
  - A dedicated **CloudBudgetStore** that holds the same in-memory shape but delegates all persistence to CloudDataService.  
- To avoid big refactors, a practical approach: **BudgetDataStore** gets a “backend” abstraction (e.g. `LocalBackend` vs `CloudBackend`). In cloud mode the backend is CloudBackend (API); in local mode it’s LocalBackend (SQLite). BudgetDataStore’s `load()`/`save()`/add/delete call into the current backend. That way existing UI stays the same.

---

## 6. Suggested Implementation Order

1. **Backend (budget_splitter_web)**  
   - Add **POST /api/groups** (create group, add owner to group_members).  
   - Add **POST /api/groups/:groupId/members** (add trip member by name).  
   - Optionally add **POST /api/groups/from-local** for one-shot upload.

2. **iOS – Local SQLite**  
   - Add SQLite (e.g. SQLite.swift dependency), create schema (local_group, members, expenses, expense_splits).  
   - Add migration from UserDefaults → SQLite on first launch.  
   - Introduce LocalBackend (reads/writes SQLite).  
   - BudgetDataStore in local mode uses LocalBackend in load/save.

3. **iOS – Cloud API layer**  
   - Add CloudDataService: fetch groups, members, expenses; create expense; delete expense; set split paid.  
   - Map API JSON ↔ Member, Expense (and paid state).  
   - Add CloudBackend that uses CloudDataService and current groupId.

4. **iOS – Mode switching and sync**  
   - Store current cloud `groupId` (e.g. after creating or selecting group).  
   - When entering cloud after login: if no group yet, show “Create from local” or “Select existing”; if we have local data and user confirms, call upload flow (create group + members + expenses).  
   - BudgetDataStore (or app root) decides backend: if `useRemoteAPI` then CloudBackend + load from API; else LocalBackend + load from SQLite.

5. **iOS – Cloud UI fixes**  
   - Apply earlier suggestion: when in cloud and `members.isEmpty`, show same “Who is the host?” (or “Create trip” / “Select group”) instead of main tabs.  
   - Use `@ObservedObject` for AuthService.shared where appropriate.

6. **Testing**  
   - Local: add members/expenses, switch to cloud, login, confirm upload and that data appears.  
   - Cloud: add/delete expense, mark paid, switch to local, confirm local DB unchanged and cloud data still on server.

---

## 7. Summary Table

| Component | Action |
|-----------|--------|
| **Backend** | Add POST /api/groups, POST /api/groups/:groupId/members (and optionally POST /api/groups/from-local). |
| **iOS Local** | Replace UserDefaults with SQLite (schema + migration + LocalBackend); BudgetDataStore uses it when in local mode. |
| **iOS Cloud** | CloudDataService (fetch/create/delete expenses, fetch members, set split paid); CloudBackend; store current groupId; on login with local data, upload group + members + expenses. |
| **iOS App flow** | Local mode: read/write SQLite. Cloud mode: read/write via API for current group; on “switch to cloud” + login, offer (or auto) upload local → new group. |

---

## 8. What I Need From You Before Implementing

- **Confirm:** Do you want me to implement **backend changes in budget_splitter_web** (POST groups, POST members), or will you do that separately? If I should do it, I’ll add those routes in `routes/vps.js`.
- **SQLite library:** Prefer **SQLite.swift** (Swift Package) or avoid SPM and use **raw sqlite3** (system framework)? SQLite.swift is easier to use.
- **Minimum iOS version:** Is iOS 17+ acceptable for SwiftData, or should we stick with SQLite for broader support?
- **Cloud “upload on switch”:** Prefer **automatic** (after login, if local data exists, create group and upload) or **manual** (after login, show “Upload this trip to cloud?” button)?

Once you confirm these, implementation can follow this plan step by step.
