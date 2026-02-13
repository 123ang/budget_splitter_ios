# Cloud Sync Developer Guide

> **Architecture: Option A — Cloud-First with Local Cache**
>
> The server (PostgreSQL) is the **source of truth**. The iOS app keeps a local SQLite cache
> so it works offline. When connectivity returns, the app pushes queued changes and pulls
> the latest server state.

---

## Table of Contents

1. [What is "Cloud Mode with Offline Caching"?](#1-what-is-cloud-mode-with-offline-caching)
2. [High-Level Architecture](#2-high-level-architecture)
3. [Data Model Alignment (iOS ↔ API)](#3-data-model-alignment-ios--api)
4. [API Schema Upgrades](#4-api-schema-upgrades)
5. [Full API Endpoint Reference](#5-full-api-endpoint-reference)
6. [Who Owes Whom — Balances Algorithm](#6-who-owes-whom--balances-algorithm)
7. [iOS App Changes](#7-ios-app-changes)
8. [Sync Protocol](#8-sync-protocol)
9. [Offline Queue](#9-offline-queue)
10. [Invite & Join Flow](#10-invite--join-flow)
11. [User Flows (Step-by-Step)](#11-user-flows-step-by-step)
12. [Security Considerations](#12-security-considerations)
13. [Implementation Phases](#13-implementation-phases)
14. [File Change Map](#14-file-change-map)

---

## 1. What is "Cloud Mode with Offline Caching"?

### The Problem

Users want to:
- Split expenses with friends on a trip
- Everyone sees the **same data** on their own phone
- Know **who owes whom** in real-time
- Still use the app when there's **no internet** (airplane, remote areas)

### The Solution: Cloud-First + Local Cache

```
┌─────────────────────────────────────────────────────────────────┐
│                         HOW IT WORKS                            │
│                                                                 │
│  ┌──────────┐          ┌──────────┐          ┌──────────┐      │
│  │ iPhone A │ ───────▶ │  Server  │ ◀─────── │ iPhone B │      │
│  │ (Ali)    │ ◀─────── │ (Source  │ ───────▶ │ (Bob)    │      │
│  │          │   HTTPS  │ of Truth)│  HTTPS   │          │      │
│  │ SQLite   │          │ Postgres │          │ SQLite   │      │
│  │ (cache)  │          │          │          │ (cache)  │      │
│  └──────────┘          └──────────┘          └──────────┘      │
│                                                                 │
│  ONLINE:  Read/write goes to server → server responds →         │
│           local SQLite is updated with server response           │
│                                                                 │
│  OFFLINE: Read/write goes to local SQLite → changes are          │
│           queued → when online again, queued changes are          │
│           pushed to server and latest data is pulled              │
└─────────────────────────────────────────────────────────────────┘
```

### Key Principles

| Principle | Description |
|-----------|-------------|
| **Server = Source of Truth** | When online, server data wins. All devices see the same state. |
| **Local = Cache + Offline Buffer** | SQLite stores a copy of server data for fast reads and offline use. |
| **Queue When Offline** | Writes (add expense, add member, etc.) are saved locally and queued. When online, the queue is flushed to the server. |
| **Pull on Launch** | Every time the app opens or returns to foreground, it pulls latest data from the server. |
| **Conflict = Last Write Wins** | If two people edit the same expense offline, the last one to sync wins. `updated_at` timestamps are used to detect this. This is acceptable for this app because conflicts are rare (people rarely edit the same expense simultaneously). |

### How It Differs from "Local Mode"

| Aspect | Local Mode (current) | Cloud Mode |
|--------|---------------------|------------|
| Data lives in | SQLite on this device only | Server (PostgreSQL) + local cache |
| Multi-device | No | Yes — all devices see same data |
| Multi-user | No — one phone, one person manages | Yes — each person has their own account |
| Offline | Always works | Works offline, syncs when online |
| Account needed | No | Yes — email + password |
| Who owes whom | Only the phone owner sees it | Everyone in the trip sees it |

---

## 2. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                            iOS App                                  │
│                                                                     │
│  ┌───────────────┐  ┌───────────────┐  ┌────────────────────────┐  │
│  │ SwiftUI Views │  │ BudgetData-   │  │ SyncService            │  │
│  │ (unchanged)   │──│ Store         │──│ - fetchGroups()        │  │
│  │               │  │ (reads from   │  │ - syncGroup(id)        │  │
│  │               │  │  local cache) │  │ - pushOfflineQueue()   │  │
│  │               │  │               │  │ - createGroup()        │  │
│  │               │  │ CloudData-    │  │ - addExpense()         │  │
│  │               │  │ Store         │  │ - fetchBalances()      │  │
│  │               │  │ (cloud mode)  │  │ - joinGroup(code)      │  │
│  └───────────────┘  └───────────────┘  └────────┬───────────────┘  │
│                                                  │                  │
│  ┌───────────────┐  ┌───────────────┐           │                  │
│  │ AuthService   │  │ OfflineQueue  │           │                  │
│  │ (login/       │  │ (SQLite table │           │                  │
│  │  register)    │  │  for pending  │           │                  │
│  │               │  │  changes)     │           │                  │
│  └───────────────┘  └───────────────┘           │                  │
│                                                  │ HTTPS            │
└──────────────────────────────────────────────────┼──────────────────┘
                                                   │
                                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          VPS API (Node.js)                          │
│                                                                     │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────────────────────┐  │
│  │ Auth     │  │ Groups/      │  │ Balances                     │  │
│  │ Routes   │  │ Expenses/    │  │ (server-computed              │  │
│  │          │  │ Members/     │  │  "who owes whom")             │  │
│  │          │  │ Settlements  │  │                               │  │
│  └──────────┘  └──────────────┘  └──────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    PostgreSQL Database                        │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. Data Model Alignment (iOS ↔ API)

### Current Gaps

| iOS Model | Current API | Action Needed |
|-----------|-------------|---------------|
| `Event` (14 fields: session type, multi-currency rates, former members, etc.) | `trip_groups` (5 fields: name, description, owner, invite code, active) | **Expand** `trip_groups` to match `Event` |
| `Currency` enum (20 values: USD, EUR, GBP, JPY, CNY, HKD, KRW, SGD, MYR, THB, IDR, PHP, VND, INR, AUD, NZD, CAD, CHF, AED, SAR) | CHECK constraint allows only JPY, MYR, SGD, USD | **Expand** to all 20 currencies |
| `Expense.payerEarned` | Not in API | **Add** column |
| `SettlementPayment` (full model with change, treated, etc.) | Only `is_paid` on `expense_splits` | **Add** `settlement_payments` table |
| `PaidExpenseMark` | Not in API | **Add** `paid_expense_marks` table |
| `Member.joinedAt` / `FormerMember.leftAt` | Not tracked | **Add** columns to `members` |
| Per-event exchange rates (`subCurrencyRatesByCode`) | Not in API | **Add** `group_currency_rates` table |
| Settlement tracking (`settledExpenseIdsByPair`, `lastSettledAtByPair`, etc.) | Not in API | **Add** `settlement_state` table |

### Target: 1-to-1 Mapping

After upgrades, every iOS model field maps directly to a server column or table:

```
iOS Event          ←→  trip_groups (expanded)
iOS Member         ←→  members (expanded)
iOS FormerMember   ←→  members WHERE left_at IS NOT NULL
iOS Expense        ←→  expenses + expense_splits
iOS SettlementPayment ←→  settlement_payments (NEW)
iOS PaidExpenseMark   ←→  paid_expense_marks (NEW)
iOS subCurrencyRatesByCode ←→  group_currency_rates (NEW)
iOS settledExpenseIdsByPair ←→  settlement_state (NEW)
```

---

## 4. API Schema Upgrades

### 4.1 Expand `trip_groups` Table

```sql
-- Match iOS Event model fields
ALTER TABLE trip_groups ADD COLUMN ended_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE trip_groups ADD COLUMN session_type VARCHAR(20) DEFAULT 'trip'
    CHECK (session_type IN ('meal', 'event', 'trip', 'activity', 'party', 'other'));
ALTER TABLE trip_groups ADD COLUMN session_type_custom VARCHAR(100);
ALTER TABLE trip_groups ADD COLUMN main_currency_code VARCHAR(3) DEFAULT 'JPY';
ALTER TABLE trip_groups ADD COLUMN sub_currency_code VARCHAR(3);
ALTER TABLE trip_groups ADD COLUMN sub_currency_rate DECIMAL(12,6);
ALTER TABLE trip_groups ADD COLUMN currency_codes TEXT; -- JSON array: ["JPY","MYR"]
```

### 4.2 Expand Currencies (All 20)

```sql
-- Drop old restrictive CHECK and add all 20 currencies
ALTER TABLE expenses DROP CONSTRAINT IF EXISTS expenses_currency_check;
ALTER TABLE expenses ADD CONSTRAINT expenses_currency_check
    CHECK (currency IN (
        'USD', 'EUR', 'GBP', 'JPY', 'CNY', 'HKD', 'KRW',
        'SGD', 'MYR', 'THB', 'IDR', 'PHP', 'VND', 'INR',
        'AUD', 'NZD', 'CAD', 'CHF', 'AED', 'SAR'
    ));
```

### 4.3 Expand `members` Table

```sql
ALTER TABLE members ADD COLUMN joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE members ADD COLUMN left_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE members ADD COLUMN is_active BOOLEAN DEFAULT TRUE;
```

### 4.4 Expand `expenses` Table

```sql
ALTER TABLE expenses ADD COLUMN payer_earned DECIMAL(12,2) DEFAULT 0;
```

### 4.5 New: `group_currency_rates` Table

Stores per-group exchange rates (iOS `subCurrencyRatesByCode`).

```sql
CREATE TABLE group_currency_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES trip_groups(id) ON DELETE CASCADE,
    from_currency VARCHAR(3) NOT NULL,
    to_currency VARCHAR(3) NOT NULL,
    rate DECIMAL(12,6) NOT NULL CHECK (rate > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(group_id, from_currency, to_currency)
);
CREATE INDEX idx_gcr_group ON group_currency_rates(group_id);
```

### 4.6 New: `settlement_payments` Table

Matches iOS `SettlementPayment` exactly.

```sql
CREATE TABLE settlement_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES trip_groups(id) ON DELETE CASCADE,
    debtor_member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    creditor_member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    note TEXT,
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    amount_received DECIMAL(12,2),
    change_given_back DECIMAL(12,2),
    amount_treated DECIMAL(12,2),
    payment_for_expense_ids UUID[], -- Array of expense IDs this payment covers
    created_by_user_id UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_sp_group ON settlement_payments(group_id);
CREATE INDEX idx_sp_debtor ON settlement_payments(debtor_member_id);
CREATE INDEX idx_sp_creditor ON settlement_payments(creditor_member_id);
```

### 4.7 New: `paid_expense_marks` Table

Matches iOS `PaidExpenseMark` (checkbox: "this debtor paid this expense to this creditor").

```sql
CREATE TABLE paid_expense_marks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES trip_groups(id) ON DELETE CASCADE,
    debtor_member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    creditor_member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    marked_by_user_id UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(group_id, debtor_member_id, creditor_member_id, expense_id)
);
```

### 4.8 New: `settlement_state` Table

Per-pair settlement tracking (iOS `settledExpenseIdsByPair`, `lastSettledAtByPair`, `paymentCutoffAtByPair`).

```sql
CREATE TABLE settlement_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES trip_groups(id) ON DELETE CASCADE,
    debtor_member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    creditor_member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    settled_expense_ids UUID[], -- Expense IDs already settled
    last_settled_at TIMESTAMP WITH TIME ZONE,
    payment_cutoff_at TIMESTAMP WITH TIME ZONE,
    lifetime_treated DECIMAL(12,2) DEFAULT 0,
    lifetime_change DECIMAL(12,2) DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(group_id, debtor_member_id, creditor_member_id)
);
```

### 4.9 Migration Script

All changes are additive (ALTER TABLE ADD COLUMN, CREATE TABLE). No data is lost.
Create: `database/migration_v2_cloud_sync.sql`

---

## 5. Full API Endpoint Reference

### Auth (unchanged)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/register` | No | Create account (email, password, displayName) |
| POST | `/auth/login` | No | Login → returns JWT token |
| POST | `/auth/logout` | Yes | Invalidate token |
| GET | `/auth/me` | Yes | Get current user profile |

### Groups

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/groups` | Yes | List all groups user belongs to (owner or member) |
| POST | `/api/groups` | Yes | Create a new group/trip |
| GET | `/api/groups/:id` | Yes | Get group detail (includes currency rates) |
| PUT | `/api/groups/:id` | Yes | Update group (name, currencies, session type, ended_at) |
| DELETE | `/api/groups/:id` | Yes | Soft-delete (archive) a group |
| POST | `/api/groups/join` | Yes | Join a group via invite code |

#### POST `/api/groups` — Request Body

```json
{
    "name": "Japan Trip 2026",
    "sessionType": "trip",
    "sessionTypeCustom": null,
    "mainCurrencyCode": "JPY",
    "subCurrencyCode": "MYR",
    "subCurrencyRate": 0.028,
    "currencyCodes": ["JPY", "MYR"],
    "subCurrencyRatesByCode": { "MYR": 0.028 },
    "memberNames": ["Ali", "Bob", "Carol"]
}
```

#### POST `/api/groups/join` — Request Body

```json
{
    "inviteCode": "ABC123"
}
```

### Members

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/groups/:gid/members` | Yes | List active + former members |
| POST | `/api/groups/:gid/members` | Yes | Add a member |
| PUT | `/api/groups/:gid/members/:mid` | Yes | Update member (rename) |
| DELETE | `/api/groups/:gid/members/:mid` | Yes | Remove member (sets left_at, keeps data) |
| POST | `/api/groups/:gid/members/:mid/reinvite` | Yes | Re-add a former member |

#### GET `/api/groups/:gid/members` — Response

```json
{
    "members": [
        { "id": "uuid", "name": "Ali", "joinedAt": "2026-01-15T...", "leftAt": null, "isActive": true },
        { "id": "uuid", "name": "Dave", "joinedAt": "2026-01-15T...", "leftAt": "2026-02-01T...", "isActive": false }
    ]
}
```

### Expenses

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/groups/:gid/expenses` | Yes | List expenses (non-deleted) |
| POST | `/api/groups/:gid/expenses` | Yes | Add expense with splits |
| PUT | `/api/groups/:gid/expenses/:eid` | Yes | Update expense |
| DELETE | `/api/groups/:gid/expenses/:eid` | Yes | Soft-delete expense |

#### POST `/api/groups/:gid/expenses` — Request Body

```json
{
    "description": "Ramen lunch",
    "amount": 3200,
    "currency": "JPY",
    "category": "Meal",
    "paidByMemberId": "uuid-of-ali",
    "expenseDate": "2026-02-10",
    "payerEarned": 0,
    "splits": [
        { "memberId": "uuid-of-ali", "amount": 1067 },
        { "memberId": "uuid-of-bob", "amount": 1067 },
        { "memberId": "uuid-of-carol", "amount": 1066 }
    ]
}
```

### Settlements

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/groups/:gid/settlements` | Yes | List settlement payments |
| POST | `/api/groups/:gid/settlements` | Yes | Record a payment |
| PUT | `/api/groups/:gid/settlements/:sid` | Yes | Update a payment |
| DELETE | `/api/groups/:gid/settlements/:sid` | Yes | Remove a payment |

#### POST `/api/groups/:gid/settlements` — Request Body

```json
{
    "debtorMemberId": "uuid-of-bob",
    "creditorMemberId": "uuid-of-ali",
    "amount": 1067,
    "note": "Cash at hotel",
    "paymentDate": "2026-02-12",
    "amountReceived": 1100,
    "changeGivenBack": 33,
    "amountTreated": 0,
    "paymentForExpenseIds": ["uuid-of-ramen-expense"]
}
```

### Paid Expense Marks

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/groups/:gid/paid-marks` | Yes | List all marks for this group |
| POST | `/api/groups/:gid/paid-marks` | Yes | Mark an expense as paid (checkbox) |
| DELETE | `/api/groups/:gid/paid-marks/:markId` | Yes | Unmark |

### Balances (Who Owes Whom) — **NEW, critical**

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/groups/:gid/balances` | Yes | Computed: net balances + minimal transfers |

#### GET `/api/groups/:gid/balances?currency=JPY` — Response

```json
{
    "currency": "JPY",
    "balances": [
        { "memberId": "uuid-ali", "memberName": "Ali", "totalPaid": 15000, "totalShare": 10000, "netBalance": 5000 },
        { "memberId": "uuid-bob", "memberName": "Bob", "totalPaid": 3000, "totalShare": 10000, "netBalance": -7000 },
        { "memberId": "uuid-carol", "memberName": "Carol", "totalPaid": 12000, "totalShare": 10000, "netBalance": 2000 }
    ],
    "transfers": [
        { "fromId": "uuid-bob", "fromName": "Bob", "toId": "uuid-ali", "toName": "Ali", "amount": 5000 },
        { "fromId": "uuid-bob", "fromName": "Bob", "toId": "uuid-carol", "toName": "Carol", "amount": 2000 }
    ]
}
```

### Sync

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/groups/:gid/sync?since=<ISO8601>` | Yes | Delta: all changes since timestamp |
| POST | `/api/groups/:gid/sync` | Yes | Push queued offline changes |

#### GET `/api/groups/:gid/sync?since=2026-02-10T00:00:00Z` — Response

Returns all entities updated after the given timestamp:

```json
{
    "serverTime": "2026-02-13T12:00:00Z",
    "group": { ... },
    "members": [ ... ],
    "expenses": [ ... ],
    "settlements": [ ... ],
    "paidMarks": [ ... ],
    "deletedExpenseIds": ["uuid1", "uuid2"],
    "deletedSettlementIds": [],
    "deletedPaidMarkIds": []
}
```

#### POST `/api/groups/:gid/sync` — Request Body

```json
{
    "operations": [
        { "type": "add_expense", "data": { ... }, "localId": "local-uuid", "timestamp": "..." },
        { "type": "add_settlement", "data": { ... }, "localId": "local-uuid", "timestamp": "..." },
        { "type": "delete_expense", "expenseId": "uuid", "timestamp": "..." },
        { "type": "add_member", "data": { "name": "Dave" }, "localId": "local-uuid", "timestamp": "..." }
    ]
}
```

Response maps local IDs to server IDs:

```json
{
    "results": [
        { "localId": "local-uuid", "serverId": "server-uuid", "success": true },
        { "localId": "local-uuid", "serverId": "server-uuid", "success": true }
    ],
    "serverTime": "2026-02-13T12:00:05Z"
}
```

---

## 6. Who Owes Whom — Balances Algorithm

The server computes this using the **same greedy algorithm** as the iOS `settlementTransfers()`:

```
1. For each active member in the group:
      totalPaid = SUM of expenses WHERE paid_by_member_id = this member
                  (minus payer_earned for each)
      totalShare = SUM of expense_splits WHERE member_id = this member
      netBalance = totalPaid - totalShare

2. Separate into:
      debtors  = members with negative netBalance (they owe money)
      creditors = members with positive netBalance (they are owed money)

3. Sort both lists by absolute value (largest first)

4. Greedy matching:
      While debtors and creditors remain:
          transfer = min(debtor's amount, creditor's amount)
          Record: debtor pays creditor this transfer amount
          Reduce both amounts
          Remove from list when amount reaches 0
```

This minimizes the number of transfers needed.

**Multi-currency:** The balances endpoint accepts a `currency` query parameter. The client calls it
once per currency used in the trip (or once with `currency=main` to get a converted total using
the group's exchange rates).

---

## 7. iOS App Changes

### 7.1 New Files to Create

| File | Purpose |
|------|---------|
| `Services/SyncService.swift` | All API calls for cloud mode |
| `Services/OfflineQueue.swift` | SQLite table for pending offline changes |
| `Models/CloudDataStore.swift` | ObservableObject for cloud mode (replaces BudgetDataStore when cloud) |
| `Views/Auth/JoinGroupView.swift` | Enter invite code to join a trip |
| `Views/CloudTripsHomeView.swift` | Trip list in cloud mode (fetched from server) |
| `Views/InviteCodeView.swift` | Show/share invite code for a trip |

### 7.2 Modify Existing Files

| File | Change |
|------|--------|
| `Services/AuthService.swift` | Add Keychain storage for token (production-ready) |
| `Services/AppModeStore.swift` | No change needed (already switches modes) |
| `Config/AppConfig.swift` | Set `apiBaseURL` to production server URL |
| `Views/Auth/RemoteModeRootView.swift` | Show `CloudTripsHomeView` instead of flat tabs |
| `BudgetSplitterApp.swift` | Route to cloud or local based on `AppModeStore` |

### 7.3 `SyncService.swift` — Key Methods

```swift
@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()

    @Published var isSyncing = false
    @Published var lastSyncAt: Date?
    @Published var syncError: String?

    private let auth = AuthService.shared

    // MARK: - Groups
    func fetchGroups() async throws -> [ServerGroup]
    func createGroup(_ params: CreateGroupParams) async throws -> ServerGroup
    func updateGroup(id: String, _ params: UpdateGroupParams) async throws
    func deleteGroup(id: String) async throws
    func joinGroup(inviteCode: String) async throws -> ServerGroup

    // MARK: - Members
    func fetchMembers(groupId: String) async throws -> [ServerMember]
    func addMember(groupId: String, name: String) async throws -> ServerMember
    func removeMember(groupId: String, memberId: String) async throws
    func reinviteMember(groupId: String, memberId: String) async throws

    // MARK: - Expenses
    func fetchExpenses(groupId: String) async throws -> [ServerExpense]
    func addExpense(groupId: String, _ params: AddExpenseParams) async throws -> String
    func updateExpense(groupId: String, expenseId: String, _ params: AddExpenseParams) async throws
    func deleteExpense(groupId: String, expenseId: String) async throws

    // MARK: - Settlements
    func fetchSettlements(groupId: String) async throws -> [ServerSettlement]
    func addSettlement(groupId: String, _ params: AddSettlementParams) async throws -> String
    func updateSettlement(groupId: String, settlementId: String, _ params: AddSettlementParams) async throws
    func deleteSettlement(groupId: String, settlementId: String) async throws

    // MARK: - Balances (Who Owes Whom)
    func fetchBalances(groupId: String, currency: String) async throws -> BalanceSummary

    // MARK: - Sync
    func syncGroup(groupId: String) async throws
    func pushOfflineQueue(groupId: String) async throws
}
```

### 7.4 `CloudDataStore.swift` — Mirrors BudgetDataStore for Cloud Mode

```swift
@MainActor
class CloudDataStore: ObservableObject {
    @Published var groups: [ServerGroup] = []
    @Published var selectedGroup: ServerGroup?

    // Per-group data (loaded when a group is selected)
    @Published var members: [ServerMember] = []
    @Published var expenses: [ServerExpense] = []
    @Published var settlements: [ServerSettlement] = []
    @Published var balances: BalanceSummary?

    private let sync = SyncService.shared

    func loadGroups() async { ... }
    func selectGroup(_ group: ServerGroup) async { ... }
    func refresh() async { ... }  // Pull latest for selected group
}
```

### 7.5 How Views Work in Cloud Mode

The existing views (`OverviewView`, `ExpensesListView`, `SettleUpView`, `MembersView`) continue
reading from the `@EnvironmentObject` data store. The key change is:

- **Local mode:** `BudgetDataStore` reads/writes SQLite directly
- **Cloud mode:** `CloudDataStore` reads from local cache, writes go through `SyncService`
  which calls the API then updates the local cache

The views don't need to know which mode is active. Both stores conform to the same interface.

---

## 8. Sync Protocol

### 8.1 When Sync Happens

| Trigger | Action |
|---------|--------|
| App launch (cloud mode) | Pull all groups, pull selected group detail |
| App returns to foreground | Pull selected group (delta since last sync) |
| User pulls to refresh | Pull selected group |
| User adds/edits/deletes anything | Push immediately if online; queue if offline |
| Network becomes available | Flush offline queue, then pull |

### 8.2 Sync Flow

```
┌─────────┐                              ┌──────────┐
│  Client  │                              │  Server  │
└────┬─────┘                              └────┬─────┘
     │                                         │
     │  1. GET /api/groups/:id/sync?since=T    │
     │ ──────────────────────────────────────▶  │
     │                                         │
     │  2. Response: updated entities + deletes │
     │ ◀──────────────────────────────────────  │
     │                                         │
     │  3. Apply changes to local SQLite cache  │
     │                                         │
     │  4. POST /api/groups/:id/sync           │
     │     (if offline queue has items)        │
     │ ──────────────────────────────────────▶  │
     │                                         │
     │  5. Response: localId → serverId map     │
     │ ◀──────────────────────────────────────  │
     │                                         │
     │  6. Update local IDs to server IDs       │
     │                                         │
```

### 8.3 Conflict Resolution

**Strategy: Last Write Wins (LWW)**

- Every entity has `updated_at` (server-managed, set to `NOW()` on every write).
- When the client pushes an offline change, the server checks if the entity was modified
  after the client's timestamp. If so, the server version wins and the client's change is rejected.
- The client re-pulls the latest data after push to ensure consistency.

**Why this is fine for a budget splitter:**
- Two people rarely edit the same expense at the same time.
- If it happens, the last editor's version is kept, and both users can see the result immediately.
- Settlement payments are append-only (no conflicts possible).

---

## 9. Offline Queue

### 9.1 SQLite Table

```sql
-- Added to the local SQLite database (LocalStorage)
CREATE TABLE IF NOT EXISTS offline_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id TEXT NOT NULL,
    operation_type TEXT NOT NULL,  -- 'add_expense', 'delete_expense', 'add_member', etc.
    payload TEXT NOT NULL,         -- JSON blob with the operation data
    local_id TEXT,                 -- Local UUID (to map to server UUID after push)
    created_at TEXT NOT NULL,      -- ISO 8601
    status TEXT DEFAULT 'pending'  -- 'pending', 'syncing', 'synced', 'failed'
);
```

### 9.2 Queue Operations

```swift
class OfflineQueue {
    static let shared = OfflineQueue()

    func enqueue(groupId: String, type: OperationType, payload: Codable, localId: String?)
    func pendingOperations(for groupId: String) -> [QueuedOperation]
    func markSynced(id: Int, serverId: String?)
    func markFailed(id: Int, error: String)
    func clearSynced()
    var hasPendingOperations: Bool { get }
}
```

### 9.3 Offline Write Flow

```
User taps "Add Expense" while offline:

1. SyncService.addExpense() is called
2. Detects no network → writes to local SQLite cache with a local UUID
3. Enqueues operation in offline_queue
4. UI updates immediately (reads from local cache)
5. Later, when online:
   a. pushOfflineQueue() sends all pending operations to server
   b. Server responds with server UUIDs
   c. Local cache UUIDs are replaced with server UUIDs
   d. Queue entries marked as synced
```

---

## 10. Invite & Join Flow

### How It Works

```
┌──────────┐                    ┌──────────┐                    ┌──────────┐
│ Ali       │                    │  Server  │                    │   Bob    │
│ (owner)  │                    │          │                    │  (new)   │
└────┬─────┘                    └────┬─────┘                    └────┬─────┘
     │                               │                               │
     │  Creates "Japan Trip"          │                               │
     │ ─────────────────────────────▶ │                               │
     │                               │                               │
     │  Gets invite code: "JPN26X"   │                               │
     │ ◀───────────────────────────── │                               │
     │                               │                               │
     │  Shares code via WhatsApp     │                               │
     │ ─────────────────────────────────────────────────────────────▶ │
     │                               │                               │
     │                               │  POST /api/groups/join        │
     │                               │  { "inviteCode": "JPN26X" }   │
     │                               │ ◀───────────────────────────── │
     │                               │                               │
     │                               │  Bob added to group_members    │
     │                               │  Bob added as member           │
     │                               │  Response: group data          │
     │                               │ ─────────────────────────────▶ │
     │                               │                               │
     │  Ali's app syncs              │                               │
     │  Sees Bob in members          │                               │
```

### Invite Code Generation (Server-Side)

- Generated on group creation: 6-character alphanumeric (uppercase), e.g. `JPN26X`
- Stored in `trip_groups.invite_code` (already exists in schema, UNIQUE)
- Can be regenerated by the owner if compromised

---

## 11. User Flows (Step-by-Step)

### Flow 1: First-Time Cloud User

1. User opens app (currently in local mode)
2. Goes to Settings → taps "Cloud Mode"
3. Sees Login screen → taps "Create Account"
4. Enters: email, display name, password → Register
5. Sees empty trip list → taps "+" to create trip
6. Enters trip name, currencies, session type → Create
7. Gets invite code → shares with friends
8. Adds members manually or waits for friends to join

### Flow 2: Joining a Friend's Trip

1. User downloads app → enables Cloud Mode
2. Creates account (or logs in)
3. Taps "Join Trip" → enters invite code from friend
4. Sees the trip with all expenses and "who owes whom"
5. Can add their own expenses

### Flow 3: Adding Expense (Online)

1. User opens a trip → taps "Add Expense"
2. Fills in: description, amount, currency, paid by, split with, category
3. Taps Save
4. `SyncService.addExpense()` → POST to server
5. Server creates expense + splits → returns IDs
6. Local cache updated → all views refresh
7. Other users' apps pull the new expense on next sync

### Flow 4: Adding Expense (Offline)

1. Same as above, but no internet
2. `SyncService.addExpense()` detects offline
3. Saves to local cache with a temporary local UUID
4. Enqueues in `offline_queue`
5. UI shows the expense immediately (reads from local cache)
6. Status indicator shows "1 pending change"
7. When internet returns → `pushOfflineQueue()` runs
8. Server assigns real UUIDs → local cache updated
9. Status indicator clears

### Flow 5: Checking Who Owes Whom

1. User opens a trip → taps "Settle Up" tab
2. App calls `GET /api/groups/:gid/balances?currency=JPY`
3. Server computes net balances + minimal transfers
4. UI shows: "Bob owes Ali ¥5,000" / "Bob owes Carol ¥2,000"
5. Bob taps "Pay" → records settlement payment
6. All users see updated balances

---

## 12. Security Considerations

| Area | Approach |
|------|----------|
| Token storage | **Keychain** (upgrade from UserDefaults). Secure, encrypted, persists across reinstalls. |
| API calls | All over **HTTPS**. Certificate pinning optional for extra security. |
| Password | **bcrypt** (12 rounds) — already implemented server-side. |
| Authorization | Every API call checks group membership. Users can only see/edit groups they belong to. |
| Token expiry | 30 days. Refreshed on each use (`last_used_at`). Expired tokens rejected. |
| Rate limiting | Auth endpoints: 10/15min. API: 100/min. Already implemented. |
| Invite codes | 6-char, unique. Owner can regenerate if compromised. Optional: add expiry. |
| Soft delete | Expenses and settlements use `is_deleted` flag — data is recoverable by admin. |

---

## 13. Implementation Phases

### Phase 1: API Schema + Core Endpoints (Backend)

**Goal:** Server supports all data the iOS app needs.

- [ ] Run migration script (expand tables, create new tables)
- [ ] Expand currency CHECK to all 20
- [ ] Implement group CRUD endpoints (GET detail, PUT update, DELETE archive)
- [ ] Implement `POST /api/groups/join` (invite code flow)
- [ ] Implement expanded member endpoints (PUT rename, DELETE with left_at, POST reinvite)
- [ ] Implement expanded expense endpoints (PUT update, payer_earned)
- [ ] Implement settlement payment CRUD endpoints
- [ ] Implement paid-expense-marks CRUD endpoints
- [ ] Implement `GET /api/groups/:gid/balances` (who owes whom)
- [ ] Implement `GET /api/groups/:gid/sync` (delta pull)
- [ ] Implement `POST /api/groups/:gid/sync` (batch push)

### Phase 2: SyncService + CloudDataStore (iOS)

**Goal:** iOS app can talk to the API.

- [ ] Create `SyncService.swift` with all API methods
- [ ] Create `CloudDataStore.swift` as ObservableObject
- [ ] Create server model structs (ServerGroup, ServerMember, ServerExpense, etc.)
- [ ] Upgrade `AuthService` to use Keychain
- [ ] Set `AppConfig.apiBaseURL` to production URL

### Phase 3: Cloud Mode UI (iOS)

**Goal:** User can use the app in cloud mode end-to-end.

- [ ] Create `CloudTripsHomeView.swift` (trip list from server)
- [ ] Update `RemoteModeRootView.swift` to use `CloudTripsHomeView`
- [ ] Create `JoinGroupView.swift` (enter invite code)
- [ ] Create `InviteCodeView.swift` (show/share invite code)
- [ ] Wire existing views to `CloudDataStore` when in cloud mode
- [ ] Add pull-to-refresh on trip list and trip detail
- [ ] Add sync status indicator (syncing, pending changes, last synced)

### Phase 4: Offline Support (iOS)

**Goal:** App works without internet and syncs when online.

- [ ] Create `OfflineQueue.swift` (SQLite table + queue methods)
- [ ] Modify `SyncService` to detect offline and queue changes
- [ ] Implement `pushOfflineQueue()` — flush on reconnect
- [ ] Add `NWPathMonitor` for network status detection
- [ ] Show "X pending changes" badge when offline operations are queued
- [ ] Handle ID remapping (local UUID → server UUID after push)

### Phase 5: Polish

**Goal:** Production-ready experience.

- [ ] Loading states (skeleton views while syncing)
- [ ] Error handling (network errors, auth errors, permission errors)
- [ ] Auto-retry failed sync operations
- [ ] Background app refresh (sync in background)
- [ ] Localization for new UI strings (EN/ZH/JA)
- [ ] Test multi-device scenario end-to-end

---

## 14. File Change Map

### Backend (`budget_splitter_web`)

| File | Action | Description |
|------|--------|-------------|
| `database/migration_v2_cloud_sync.sql` | **NEW** | All schema changes (ALTERs + new tables) |
| `routes/vps.js` | **MODIFY** | Add all new endpoints (groups CRUD, settlements, balances, sync, etc.) |

### iOS (`budget_splitter_ios`)

| File | Action | Description |
|------|--------|-------------|
| `Services/SyncService.swift` | **NEW** | All API calls |
| `Services/OfflineQueue.swift` | **NEW** | Offline operation queue |
| `Models/CloudDataStore.swift` | **NEW** | Cloud mode data store |
| `Models/ServerModels.swift` | **NEW** | Codable structs for API responses |
| `Views/CloudTripsHomeView.swift` | **NEW** | Trip list (cloud mode) |
| `Views/Auth/JoinGroupView.swift` | **NEW** | Enter invite code |
| `Views/InviteCodeView.swift` | **NEW** | Show/share invite code |
| `Services/AuthService.swift` | **MODIFY** | Keychain for token |
| `Config/AppConfig.swift` | **MODIFY** | Set apiBaseURL |
| `Views/Auth/RemoteModeRootView.swift` | **MODIFY** | Use CloudTripsHomeView |
| `BudgetSplitterApp.swift` | **MODIFY** | Route cloud vs local |

---

## Appendix: Supported Currencies (All 20)

| Code | Symbol | Name | Decimals |
|------|--------|------|----------|
| USD | $ | US Dollar | 2 |
| EUR | € | Euro | 2 |
| GBP | £ | British Pound | 2 |
| JPY | ¥ | Japanese Yen | 0 |
| CNY | ¥ | Chinese Yuan | 2 |
| HKD | HK$ | Hong Kong Dollar | 2 |
| KRW | ₩ | Korean Won | 0 |
| SGD | S$ | Singapore Dollar | 2 |
| MYR | RM | Malaysian Ringgit | 2 |
| THB | ฿ | Thai Baht | 2 |
| IDR | Rp | Indonesian Rupiah | 2 |
| PHP | ₱ | Philippine Peso | 2 |
| VND | ₫ | Vietnamese Dong | 0 |
| INR | ₹ | Indian Rupee | 2 |
| AUD | A$ | Australian Dollar | 2 |
| NZD | NZ$ | New Zealand Dollar | 2 |
| CAD | C$ | Canadian Dollar | 2 |
| CHF | CHF | Swiss Franc | 2 |
| AED | AED | UAE Dirham | 2 |
| SAR | SAR | Saudi Riyal | 2 |
