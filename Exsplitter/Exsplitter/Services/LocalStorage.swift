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
            payer_earned REAL
        );
        CREATE TABLE IF NOT EXISTS expense_splits (
            id TEXT PRIMARY KEY,
            expense_id TEXT NOT NULL,
            member_id TEXT NOT NULL,
            amount REAL NOT NULL,
            FOREIGN KEY (expense_id) REFERENCES expenses(id),
            FOREIGN KEY (member_id) REFERENCES members(id)
        );
        CREATE TABLE IF NOT EXISTS key_value (
            key TEXT PRIMARY KEY,
            value BLOB
        );
        """
        sqlite3_exec(db, sql, nil, nil, nil)
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

        saveAll(members: members, expenses: expenses, selectedMemberIds: selectedIds, settledMemberIds: settledIds, settlementPayments: payments, paidExpenseMarks: paidMarks)
    }

    struct Snapshot {
        var members: [Member]
        var expenses: [Expense]
        var selectedMemberIds: Set<String>
        var settledMemberIds: Set<String>
        var settlementPayments: [SettlementPayment]
        var paidExpenseMarks: [PaidExpenseMark]
    }

    func loadAll() -> Snapshot {
        guard let db = db else {
            return Snapshot(members: [], expenses: [], selectedMemberIds: [], settledMemberIds: [], settlementPayments: [], paidExpenseMarks: [])
        }
        var members: [Member] = []
        var expenses: [Expense] = []
        var selectedIds: Set<String> = []
        var settledIds: Set<String> = []
        var payments: [SettlementPayment] = []
        var paidMarks: [PaidExpenseMark] = []

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT id, name FROM members ORDER BY name", -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                members.append(Member(id: id, name: name))
            }
        }

        if sqlite3_prepare_v2(db, "SELECT id, description, amount, currency, category, paid_by_member_id, expense_date, created_at, payer_earned FROM expenses ORDER BY expense_date DESC, created_at DESC", -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dateFormatterFallback = ISO8601DateFormatter()
            dateFormatterFallback.formatOptions = [.withInternetDateTime]
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

                let shortFormatter = DateFormatter()
                shortFormatter.dateFormat = "yyyy-MM-dd"
                shortFormatter.timeZone = TimeZone(identifier: "UTC")
                let date: Date = dateFormatter.date(from: dateStr) ?? dateFormatterFallback.date(from: dateStr) ?? shortFormatter.date(from: dateStr) ?? Date()
                let createdAt: Date = (createdAtStr.flatMap { dateFormatter.date(from: $0) ?? dateFormatterFallback.date(from: $0) }) ?? date

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
                    payerEarned: payerEarned
                )
                expenses.append(exp)
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

        if selectedIds.isEmpty && !members.isEmpty {
            selectedIds = Set(members.map(\.id))
        }
        let memberIdSet = Set(members.map(\.id))
        selectedIds = selectedIds.filter { memberIdSet.contains($0) }
        settledIds = settledIds.filter { memberIdSet.contains($0) }

        return Snapshot(members: members, expenses: expenses, selectedMemberIds: selectedIds, settledMemberIds: settledIds, settlementPayments: payments, paidExpenseMarks: paidMarks)
    }

    private func getBlob(key: String) -> Data? {
        guard let db = db else { return nil }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT value FROM key_value WHERE key = ?", -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)
        guard sqlite3_step(stmt) == SQLITE_ROW, let bytes = sqlite3_column_blob(stmt, 0) else { return nil }
        let count = sqlite3_column_bytes(stmt, 0)
        return Data(bytes: bytes, count: count)
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

    func saveAll(members: [Member], expenses: [Expense], selectedMemberIds: Set<String>, settledMemberIds: Set<String>, settlementPayments: [SettlementPayment], paidExpenseMarks: [PaidExpenseMark]) {
        guard let db = db else { return }
        guard sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil) == SQLITE_OK else { return }

        sqlite3_exec(db, "DELETE FROM expense_splits", nil, nil, nil)
        sqlite3_exec(db, "DELETE FROM expenses", nil, nil, nil)
        sqlite3_exec(db, "DELETE FROM members", nil, nil, nil)

        var insertMember: OpaquePointer?
        if sqlite3_prepare_v2(db, "INSERT INTO members (id, name, created_at) VALUES (?, ?, ?)", -1, &insertMember, nil) == SQLITE_OK {
            defer { sqlite3_finalize(insertMember) }
            let now = ISO8601DateFormatter().string(from: Date())
            for m in members {
                sqlite3_bind_text(insertMember, 1, (m.id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertMember, 2, (m.name as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertMember, 3, (now as NSString).utf8String, -1, nil)
                sqlite3_step(insertMember)
                sqlite3_reset(insertMember)
            }
        }

        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
        dateOnlyFormatter.timeZone = TimeZone(identifier: "UTC")
        var insertExpense: OpaquePointer?
        var insertSplit: OpaquePointer?
        if sqlite3_prepare_v2(db, "INSERT INTO expenses (id, description, amount, currency, category, paid_by_member_id, expense_date, created_at, payer_earned) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", -1, &insertExpense, nil) == SQLITE_OK,
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

        _ = sqlite3_exec(db, "COMMIT", nil, nil, nil)
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
}
