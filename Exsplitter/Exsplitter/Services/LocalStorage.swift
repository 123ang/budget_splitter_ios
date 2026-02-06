//
//  LocalStorage.swift
//  Exsplitter
//
//  SQLite-backed local storage for members, expenses, and related state.
//  Migrates from UserDefaults on first run.
//

import Foundation
import SQLite3

final class LocalStorage {
    static let shared = LocalStorage()

    private let dbPath: String
    private let migrationKey = "BudgetSplitter_migratedToSQLite"
    private let membersKey = "BudgetSplitter_members"
    private let expensesKey = "BudgetSplitter_expenses"
    private let selectedKey = "BudgetSplitter_selected"
    private let settledKey = "BudgetSplitter_settled"
    private let settlementPaymentsKey = "BudgetSplitter_settlementPayments"
    private let paidExpenseMarksKey = "BudgetSplitter_paidExpenseMarks"
    private let settledExpenseIdsByPairKey = "BudgetSplitter_settledExpenseIdsByPair"
    private let eventsKey = "BudgetSplitter_events"

    private init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Exsplitter", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        dbPath = dir.appendingPathComponent("budget_splitter_local.db").path
        openAndPrepare()
    }

    private var db: OpaquePointer?

    private func openAndPrepare() {
        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) != SQLITE_OK {
            return
        }
        createTables()
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            migrateFromUserDefaults()
            UserDefaults.standard.set(true, forKey: migrationKey)
        }
    }

    private func createTables() {
        let sql = """
        CREATE TABLE IF NOT EXISTS members (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at TEXT
        );
        CREATE TABLE IF NOT EXISTS expenses (
            id TEXT PRIMARY KEY,
            description TEXT,
            amount REAL NOT NULL,
            currency TEXT DEFAULT 'JPY',
            category TEXT NOT NULL,
            paid_by_member_id TEXT NOT NULL,
            expense_date TEXT NOT NULL,
            created_at TEXT,
            payer_earned REAL,
            event_id TEXT
        );
        CREATE TABLE IF NOT EXISTS expense_splits (
            id TEXT PRIMARY KEY,
            expense_id TEXT NOT NULL,
            member_id TEXT NOT NULL,
            amount REAL NOT NULL,
            FOREIGN KEY (expense_id) REFERENCES expenses(id),
            FOREIGN KEY (member_id) REFERENCES members(id)
        );
        CREATE TABLE IF NOT EXISTS events (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at TEXT,
            ended_at TEXT
        );
        CREATE TABLE IF NOT EXISTS key_value (
            key TEXT PRIMARY KEY,
            value BLOB
        );
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        migrateAddEventIdIfNeeded()
        migrateEventsMemberIdsCurrenciesIfNeeded()
        migrateEventsMembersIfNeeded()
        migrateMembersJoinedAtIfNeeded()
    }
    
    /// Events table: add members column (JSON array of Member) if missing. Per-trip members so data is not shared between trips.
    private func migrateEventsMembersIfNeeded() {
        guard let db = db else { return }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA table_info(events)", -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            var hasMembers = false
            while sqlite3_step(stmt) == SQLITE_ROW {
                let name = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                if name == "members" { hasMembers = true; break }
            }
            if !hasMembers { sqlite3_exec(db, "ALTER TABLE events ADD COLUMN members TEXT", nil, nil, nil) }
        }
    }

    /// Members table: add joined_at column if missing (ISO8601 date when member joined the group).
    private func migrateMembersJoinedAtIfNeeded() {
        guard let db = db else { return }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA table_info(members)", -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            var hasJoinedAt = false
            while sqlite3_step(stmt) == SQLITE_ROW {
                let name = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                if name == "joined_at" { hasJoinedAt = true; break }
            }
            if !hasJoinedAt { sqlite3_exec(db, "ALTER TABLE members ADD COLUMN joined_at TEXT", nil, nil, nil) }
        }
    }

    /// Events table: add member_ids and currencies columns if missing (JSON strings).
    private func migrateEventsMemberIdsCurrenciesIfNeeded() {
        guard let db = db else { return }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA table_info(events)", -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            var hasMemberIds = false, hasCurrencies = false
            while sqlite3_step(stmt) == SQLITE_ROW {
                let name = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                if name == "member_ids" { hasMemberIds = true }
                if name == "currencies" { hasCurrencies = true }
            }
            if !hasMemberIds { sqlite3_exec(db, "ALTER TABLE events ADD COLUMN member_ids TEXT", nil, nil, nil) }
            if !hasCurrencies { sqlite3_exec(db, "ALTER TABLE events ADD COLUMN currencies TEXT", nil, nil, nil) }
        }
    }

    /// Existing DBs have expenses without event_id; add column if missing.
    private func migrateAddEventIdIfNeeded() {
        guard let db = db else { return }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA table_info(expenses)", -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            var hasEventId = false
            while sqlite3_step(stmt) == SQLITE_ROW {
                let name = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                if name == "event_id" { hasEventId = true; break }
            }
            if !hasEventId {
                sqlite3_exec(db, "ALTER TABLE expenses ADD COLUMN event_id TEXT", nil, nil, nil)
            }
        }
    }

    private func migrateFromUserDefaults() {
        let ud = UserDefaults.standard
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var members: [Member] = []
        var expenses: [Expense] = []
        var selectedIds: Set<String> = []
        var settledIds: Set<String> = []
        var payments: [SettlementPayment] = []
        var paidMarks: [PaidExpenseMark] = []

        if let data = ud.data(forKey: membersKey),
           let decoded = try? decoder.decode([Member].self, from: data) {
            members = decoded
        }
        if let data = ud.data(forKey: expensesKey),
           let decoded = try? decoder.decode([Expense].self, from: data) {
            expenses = decoded
        }
        if let ids = ud.stringArray(forKey: selectedKey), !ids.isEmpty {
            selectedIds = Set(ids)
        }
        if let ids = ud.stringArray(forKey: settledKey) {
            settledIds = Set(ids)
        }
        if let data = ud.data(forKey: settlementPaymentsKey),
           let decoded = try? JSONDecoder().decode([SettlementPayment].self, from: data) {
            payments = decoded
        }
        if let data = ud.data(forKey: paidExpenseMarksKey),
           let decoded = try? JSONDecoder().decode([PaidExpenseMark].self, from: data) {
            paidMarks = decoded
        }

        saveAll(members: members, expenses: expenses, selectedMemberIds: selectedIds, settledMemberIds: settledIds, settlementPayments: payments, paidExpenseMarks: paidMarks, events: [])
    }

    struct Snapshot {
        var members: [Member]
        var expenses: [Expense]
        var selectedMemberIds: Set<String>
        var settledMemberIds: Set<String>
        var settlementPayments: [SettlementPayment]
        var paidExpenseMarks: [PaidExpenseMark]
        /// Expense IDs considered settled per (debtorId|creditorId). When "Mark as fully paid", we add current expense IDs so new expenses don't mix with old.
        var settledExpenseIdsByPair: [String: [String]]
        var events: [Event]
    }

    func loadAll() -> Snapshot {
        guard let db = db else {
            return Snapshot(members: [], expenses: [], selectedMemberIds: [], settledMemberIds: [], settlementPayments: [], paidExpenseMarks: [], settledExpenseIdsByPair: [:], events: [])
        }
        var members: [Member] = []
        var expenses: [Expense] = []
        var selectedIds: Set<String> = []
        var settledIds: Set<String> = []
        var payments: [SettlementPayment] = []
        var paidMarks: [PaidExpenseMark] = []
        var events: [Event] = []

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT id, name, created_at, joined_at FROM members ORDER BY name", -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let colCount = sqlite3_column_count(stmt)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let createdAtStr = colCount > 2 ? sqlite3_column_text(stmt, 2).map { String(cString: $0) } : nil
                let joinedAtStr = colCount > 3 ? sqlite3_column_text(stmt, 3).map { String(cString: $0) } : nil
                let joinedAt = joinedAtStr.flatMap { dateFormatter.date(from: $0) }
                    ?? createdAtStr.flatMap { dateFormatter.date(from: $0) }
                members.append(Member(id: id, name: name, joinedAt: joinedAt))
            }
        }

        if sqlite3_prepare_v2(db, "SELECT id, description, amount, currency, category, paid_by_member_id, expense_date, created_at, payer_earned, event_id FROM expenses ORDER BY expense_date DESC, created_at DESC", -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dateFormatterFallback = ISO8601DateFormatter()
            dateFormatterFallback.formatOptions = [.withInternetDateTime]
            let colCount = sqlite3_column_count(stmt)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let description = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                let amount = sqlite3_column_double(stmt, 2)
                let currency = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "JPY"
                let category = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "Other"
                let paidBy = String(cString: sqlite3_column_text(stmt, 5))
                let dateStr = String(cString: sqlite3_column_text(stmt, 6))
                let createdAtStr = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
                let payerEarned = sqlite3_column_type(stmt, 8) == SQLITE_NULL ? nil : Optional(sqlite3_column_double(stmt, 8))
                let eventId: String? = colCount > 9 && sqlite3_column_type(stmt, 9) != SQLITE_NULL ? sqlite3_column_text(stmt, 9).map { String(cString: $0) } : nil

                let shortFormatter = DateFormatter()
                shortFormatter.dateFormat = "yyyy-MM-dd"
                shortFormatter.timeZone = TimeZone(identifier: "UTC")
                let date: Date = dateFormatter.date(from: dateStr) ?? dateFormatterFallback.date(from: dateStr) ?? shortFormatter.date(from: dateStr) ?? Date()
                _ = (createdAtStr.flatMap { dateFormatter.date(from: $0) ?? dateFormatterFallback.date(from: $0) }) ?? date

                var splitMemberIds: [String] = []
                var splits: [String: Double] = [:]
                var splitStmt: OpaquePointer?
                if sqlite3_prepare_v2(db, "SELECT member_id, amount FROM expense_splits WHERE expense_id = ?", -1, &splitStmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(splitStmt, 1, (id as NSString).utf8String, -1, nil)
                    while sqlite3_step(splitStmt) == SQLITE_ROW {
                        let mid = String(cString: sqlite3_column_text(splitStmt, 0))
                        let amt = sqlite3_column_double(splitStmt, 1)
                        splitMemberIds.append(mid)
                        splits[mid] = amt
                    }
                    sqlite3_finalize(splitStmt)
                }

                let exp = Expense(
                    id: id,
                    description: description,
                    amount: amount,
                    category: ExpenseCategory(rawValue: category) ?? .other,
                    currency: Currency(rawValue: currency) ?? .JPY,
                    paidByMemberId: paidBy,
                    date: date,
                    splitMemberIds: splitMemberIds,
                    splits: splits,
                    payerEarned: payerEarned,
                    eventId: eventId
                )
                expenses.append(exp)
            }
        }

        if sqlite3_prepare_v2(db, "SELECT id, name, created_at, ended_at, member_ids, currencies, members FROM events ORDER BY created_at DESC", -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let colCount = sqlite3_column_count(stmt)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let createdAtStr = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
                let endedAtStr = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                let createdAt = createdAtStr.flatMap { dateFormatter.date(from: $0) } ?? Date()
                let endedAt = endedAtStr.flatMap { dateFormatter.date(from: $0) }
                var memberIds: [String]? = nil
                var currencyCodes: [String]? = nil
                var eventMembers: [Member] = []
                if colCount > 4, sqlite3_column_type(stmt, 4) != SQLITE_NULL, let data = sqlite3_column_text(stmt, 4).map({ String(cString: $0) }), let d = data.data(using: .utf8), let decoded = try? JSONDecoder().decode([String].self, from: d) {
                    memberIds = decoded
                }
                if colCount > 5, sqlite3_column_type(stmt, 5) != SQLITE_NULL, let data = sqlite3_column_text(stmt, 5).map({ String(cString: $0) }), let d = data.data(using: .utf8), let decoded = try? JSONDecoder().decode([String].self, from: d) {
                    currencyCodes = decoded
                }
                if colCount > 6, sqlite3_column_type(stmt, 6) != SQLITE_NULL, let data = sqlite3_column_text(stmt, 6).map({ String(cString: $0) }), let d = data.data(using: .utf8), let decoded = try? JSONDecoder().decode([Member].self, from: d) {
                    eventMembers = decoded
                }
                events.append(Event(id: id, name: name, createdAt: createdAt, endedAt: endedAt, memberIds: memberIds, currencyCodes: currencyCodes, members: eventMembers))
            }
        }

        if let data = getBlob(key: selectedKey), let ids = try? JSONDecoder().decode([String].self, from: data), !ids.isEmpty {
            selectedIds = Set(ids)
        }
        if let data = getBlob(key: settledKey), let ids = try? JSONDecoder().decode([String].self, from: data) {
            settledIds = Set(ids)
        }
        if let data = getBlob(key: settlementPaymentsKey), let decoded = try? JSONDecoder().decode([SettlementPayment].self, from: data) {
            payments = decoded
        }
        if let data = getBlob(key: paidExpenseMarksKey), let decoded = try? JSONDecoder().decode([PaidExpenseMark].self, from: data) {
            paidMarks = decoded
        }
        var settledByPair: [String: [String]] = [:]
        if let data = getBlob(key: settledExpenseIdsByPairKey), let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            settledByPair = decoded
        }

        if selectedIds.isEmpty && !members.isEmpty {
            selectedIds = Set(members.map(\.id))
        }
        let memberIdSet = Set(members.map(\.id))
        selectedIds = selectedIds.filter { memberIdSet.contains($0) }
        settledIds = settledIds.filter { memberIdSet.contains($0) }

        return Snapshot(members: members, expenses: expenses, selectedMemberIds: selectedIds, settledMemberIds: settledIds, settlementPayments: payments, paidExpenseMarks: paidMarks, settledExpenseIdsByPair: settledByPair, events: events)
    }

    private func getBlob(key: String) -> Data? {
        guard let db = db else { return nil }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT value FROM key_value WHERE key = ?", -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)
        guard sqlite3_step(stmt) == SQLITE_ROW, let bytes = sqlite3_column_blob(stmt, 0) else { return nil }
        let count = sqlite3_column_bytes(stmt, 0)
        return Data(bytes: bytes, count: Int(count))
    }

    private func setBlob(key: String, value: Data) {
        guard let db = db else { return }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO key_value (key, value) VALUES (?, ?)", -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            value.withUnsafeBytes { buf in
                sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)
                sqlite3_bind_blob(stmt, 2, buf.baseAddress, Int32(value.count), nil)
                sqlite3_step(stmt)
            }
        }
    }

    func saveAll(members: [Member], expenses: [Expense], selectedMemberIds: Set<String>, settledMemberIds: Set<String>, settlementPayments: [SettlementPayment], paidExpenseMarks: [PaidExpenseMark], settledExpenseIdsByPair: [String: [String]] = [:], events: [Event] = []) {
        guard let db = db else { return }
        guard sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil) == SQLITE_OK else { return }

        sqlite3_exec(db, "DELETE FROM expense_splits", nil, nil, nil)
        sqlite3_exec(db, "DELETE FROM expenses", nil, nil, nil)
        sqlite3_exec(db, "DELETE FROM events", nil, nil, nil)
        sqlite3_exec(db, "DELETE FROM members", nil, nil, nil)

        var insertMember: OpaquePointer?
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if sqlite3_prepare_v2(db, "INSERT INTO members (id, name, created_at, joined_at) VALUES (?, ?, ?, ?)", -1, &insertMember, nil) == SQLITE_OK {
            defer { sqlite3_finalize(insertMember) }
            let now = dateFormatter.string(from: Date())
            for m in members {
                sqlite3_bind_text(insertMember, 1, (m.id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertMember, 2, (m.name as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertMember, 3, (now as NSString).utf8String, -1, nil)
                if let j = m.joinedAt {
                    sqlite3_bind_text(insertMember, 4, (dateFormatter.string(from: j) as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_text(insertMember, 4, (now as NSString).utf8String, -1, nil)
                }
                sqlite3_step(insertMember)
                sqlite3_reset(insertMember)
            }
        }

        var insertEvent: OpaquePointer?
        if sqlite3_prepare_v2(db, "INSERT INTO events (id, name, created_at, ended_at, member_ids, currencies, members) VALUES (?, ?, ?, ?, ?, ?, ?)", -1, &insertEvent, nil) == SQLITE_OK {
            defer { sqlite3_finalize(insertEvent) }
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            for ev in events {
                sqlite3_bind_text(insertEvent, 1, (ev.id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertEvent, 2, (ev.name as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertEvent, 3, (dateFormatter.string(from: ev.createdAt) as NSString).utf8String, -1, nil)
                if let end = ev.endedAt {
                    sqlite3_bind_text(insertEvent, 4, (dateFormatter.string(from: end) as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(insertEvent, 4)
                }
                if let ids = ev.memberIds, let data = try? JSONEncoder().encode(ids), let str = String(data: data, encoding: .utf8) {
                    sqlite3_bind_text(insertEvent, 5, (str as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(insertEvent, 5)
                }
                if let codes = ev.currencyCodes, let data = try? JSONEncoder().encode(codes), let str = String(data: data, encoding: .utf8) {
                    sqlite3_bind_text(insertEvent, 6, (str as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(insertEvent, 6)
                }
                if !ev.members.isEmpty, let data = try? JSONEncoder().encode(ev.members), let str = String(data: data, encoding: .utf8) {
                    sqlite3_bind_text(insertEvent, 7, (str as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(insertEvent, 7)
                }
                sqlite3_step(insertEvent)
                sqlite3_reset(insertEvent)
            }
        }

        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
        dateOnlyFormatter.timeZone = TimeZone(identifier: "UTC")
        var insertExpense: OpaquePointer?
        var insertSplit: OpaquePointer?
        if sqlite3_prepare_v2(db, "INSERT INTO expenses (id, description, amount, currency, category, paid_by_member_id, expense_date, created_at, payer_earned, event_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", -1, &insertExpense, nil) == SQLITE_OK,
           sqlite3_prepare_v2(db, "INSERT INTO expense_splits (id, expense_id, member_id, amount) VALUES (?, ?, ?, ?)", -1, &insertSplit, nil) == SQLITE_OK {
            defer { sqlite3_finalize(insertExpense); sqlite3_finalize(insertSplit) }
            for e in expenses {
                let dateStr = dateOnlyFormatter.string(from: e.date)
                sqlite3_bind_text(insertExpense, 1, (e.id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertExpense, 2, (e.description as NSString).utf8String, -1, nil)
                sqlite3_bind_double(insertExpense, 3, e.amount)
                sqlite3_bind_text(insertExpense, 4, (e.currency.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertExpense, 5, (e.category.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertExpense, 6, (e.paidByMemberId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertExpense, 7, (dateStr as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertExpense, 8, (ISO8601DateFormatter().string(from: e.date) as NSString).utf8String, -1, nil)
                if let pe = e.payerEarned {
                    sqlite3_bind_double(insertExpense, 9, pe)
                } else {
                    sqlite3_bind_null(insertExpense, 9)
                }
                if let eid = e.eventId {
                    sqlite3_bind_text(insertExpense, 10, (eid as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(insertExpense, 10)
                }
                sqlite3_step(insertExpense)
                sqlite3_reset(insertExpense)

                for (memberId, amount) in e.splits {
                    let splitId = UUID().uuidString
                    sqlite3_bind_text(insertSplit, 1, (splitId as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(insertSplit, 2, (e.id as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(insertSplit, 3, (memberId as NSString).utf8String, -1, nil)
                    sqlite3_bind_double(insertSplit, 4, amount)
                    sqlite3_step(insertSplit)
                    sqlite3_reset(insertSplit)
                }
            }
        }

        if let data = try? JSONEncoder().encode(Array(selectedMemberIds)) {
            setBlob(key: selectedKey, value: data)
        }
        if let data = try? JSONEncoder().encode(Array(settledMemberIds)) {
            setBlob(key: settledKey, value: data)
        }
        if let data = try? JSONEncoder().encode(settlementPayments) {
            setBlob(key: settlementPaymentsKey, value: data)
        }
        if let data = try? JSONEncoder().encode(paidExpenseMarks) {
            setBlob(key: paidExpenseMarksKey, value: data)
        }
        if let data = try? JSONEncoder().encode(settledExpenseIdsByPair) {
            setBlob(key: settledExpenseIdsByPairKey, value: data)
        }

        _ = sqlite3_exec(db, "COMMIT", nil, nil, nil)
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
}
