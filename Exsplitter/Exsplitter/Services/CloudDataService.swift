//
//  CloudDataService.swift
//  Exsplitter
//
//  API client for VPS mode: groups, members, expenses. Used for cloud read/write and upload.
//

import Foundation

struct CloudGroup: Codable {
    let id: String
    let name: String?
    let description: String?
    let owner_id: String?
    let invite_code: String?
    let is_active: Bool?
}

struct CloudMember: Codable {
    let id: String
    let groupId: String?
    let userId: String?
    let name: String
    let createdAt: String?
}

struct CloudExpenseSplit: Codable {
    let id: String
    let memberId: String
    let amount: Double
    let isPaid: Bool?
}

struct CloudExpense: Codable {
    let id: String
    let groupId: String?
    let description: String?
    let amount: Double
    let currency: String?
    let category: String
    let paidByMemberId: String
    let expenseDate: String
    let createdAt: String?
    let splits: [CloudExpenseSplit]?
}

@MainActor
final class CloudDataService {
    static let shared = CloudDataService()
    private let baseURL: String
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private init() {
        baseURL = AppConfig.apiBaseURL
    }

    private func token() -> String? {
        AuthService.shared.getToken()
    }

    private func request(path: String, method: String, body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        guard let token = token() else { throw APIError.unauthorized }
        guard let url = URL(string: baseURL + path) else { throw APIError.networkError("Invalid URL") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.networkError("Invalid response") }
        return (data, http)
    }

    // MARK: - Groups

    func fetchGroups() async throws -> [CloudGroup] {
        let (data, http) = try await request(path: "/api/groups", method: "GET")
        if http.statusCode != 200 {
            let err = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error ?? "Failed to fetch groups"
            throw APIError.serverError(err)
        }
        let wrapper = try JSONDecoder().decode([String: [CloudGroup]].self, from: data)
        return wrapper["groups"] ?? []
    }

    func createGroup(name: String?, description: String?) async throws -> String {
        var body: [String: Any] = [:]
        if let n = name?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
            body["name"] = n
        }
        if let d = description?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty {
            body["description"] = d
        }
        let data = try JSONSerialization.data(withJSONObject: body.isEmpty ? [:] : body)
        let (respData, http) = try await request(path: "/api/groups", method: "POST", body: data)
        if http.statusCode != 201 {
            let err = (try? JSONDecoder().decode(APIErrorResponse.self, from: respData))?.error ?? "Failed to create group"
            throw APIError.serverError(err)
        }
        let decoded = try JSONDecoder().decode([String: CloudGroup].self, from: respData)
        guard let group = decoded["group"] else { throw APIError.serverError("No group in response") }
        return group.id
    }

    // MARK: - Members

    func addMember(groupId: String, name: String) async throws -> Member {
        let body = ["name": name.trimmingCharacters(in: .whitespacesAndNewlines)]
        let data = try JSONSerialization.data(withJSONObject: body)
        let (respData, http) = try await request(path: "/api/groups/\(groupId)/members", method: "POST", body: data)
        if http.statusCode != 201 {
            let err = (try? JSONDecoder().decode(APIErrorResponse.self, from: respData))?.error ?? "Failed to add member"
            throw APIError.serverError(err)
        }
        let decoded = try JSONDecoder().decode([String: CloudMember].self, from: respData)
        guard let m = decoded["member"] else { throw APIError.serverError("No member in response") }
        return Member(id: m.id, name: m.name)
    }

    func fetchMembers(groupId: String) async throws -> [Member] {
        let (data, http) = try await request(path: "/api/groups/\(groupId)/members", method: "GET")
        if http.statusCode != 200 {
            let err = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error ?? "Failed to fetch members"
            throw APIError.serverError(err)
        }
        let wrapper = try JSONDecoder().decode([String: [CloudMember]].self, from: data)
        let list = wrapper["members"] ?? []
        return list.map { Member(id: $0.id, name: $0.name) }
    }

    // MARK: - Expenses

    func fetchExpenses(groupId: String) async throws -> [CloudExpense] {
        let (data, http) = try await request(path: "/api/groups/\(groupId)/expenses", method: "GET")
        if http.statusCode != 200 {
            let err = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error ?? "Failed to fetch expenses"
            throw APIError.serverError(err)
        }
        let wrapper = try JSONDecoder().decode([String: [CloudExpense]].self, from: data)
        return wrapper["expenses"] ?? []
    }

    func createExpense(groupId: String, description: String, amount: Double, currency: Currency, category: ExpenseCategory, paidByMemberId: String, expenseDate: Date, splits: [(memberId: String, amount: Double)]) async throws -> String {
        let dateStr = dateOnlyFormatter.string(from: expenseDate)
        let splitsPayload = splits.map { ["memberId": $0.memberId, "amount": $0.amount] }
        let body: [String: Any] = [
            "groupId": groupId,
            "description": description,
            "amount": amount,
            "currency": currency.rawValue,
            "category": category.rawValue,
            "paidByMemberId": paidByMemberId,
            "expenseDate": dateStr,
            "splits": splitsPayload
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let (respData, http) = try await request(path: "/api/expenses", method: "POST", body: data)
        if http.statusCode != 201 {
            let err = (try? JSONDecoder().decode(APIErrorResponse.self, from: respData))?.error ?? "Failed to add expense"
            throw APIError.serverError(err)
        }
        struct CreateExpenseResponse: Decodable { let expenseId: String }
        let decoded = try JSONDecoder().decode(CreateExpenseResponse.self, from: respData)
        return decoded.expenseId
    }

    func deleteExpense(expenseId: String) async throws {
        let (respData, http) = try await request(path: "/api/expenses/\(expenseId)", method: "DELETE")
        if http.statusCode != 200 {
            let err = (try? JSONDecoder().decode(APIErrorResponse.self, from: respData))?.error ?? "Failed to delete expense"
            throw APIError.serverError(err)
        }
    }

    func setSplitPaid(splitId: String, isPaid: Bool, reason: String?) async throws {
        var body: [String: Any] = ["isPaid": isPaid]
        if let r = reason, !r.isEmpty { body["reason"] = r }
        let data = try JSONSerialization.data(withJSONObject: body)
        let (respData, http) = try await request(path: "/api/expense-splits/\(splitId)/payment", method: "PATCH", body: data)
        if http.statusCode != 200 {
            let err = (try? JSONDecoder().decode(APIErrorResponse.self, from: respData))?.error ?? "Failed to update payment"
            throw APIError.serverError(err)
        }
    }

    // MARK: - Snapshot from API

    /// Fetch members and expenses for a group and convert to LocalStorage.Snapshot (for setting BudgetDataStore).
    func fetchSnapshot(groupId: String) async throws -> LocalStorage.Snapshot {
        let (members, cloudExpenses) = try await (fetchMembers(groupId: groupId), fetchExpenses(groupId: groupId))
        var expenses: [Expense] = []
        var paidExpenseMarks: [PaidExpenseMark] = []
        let memberIds = Set(members.map(\.id))
        for ce in cloudExpenses {
            var splitMemberIds: [String] = []
            var splits: [String: Double] = [:]
            for s in ce.splits ?? [] {
                splitMemberIds.append(s.memberId)
                splits[s.memberId] = s.amount
                if s.isPaid == true {
                    paidExpenseMarks.append(PaidExpenseMark(debtorId: s.memberId, creditorId: ce.paidByMemberId, expenseId: ce.id))
                }
            }
            let date: Date = dateOnlyFormatter.date(from: ce.expenseDate) ?? Date()
            let exp = Expense(
                id: ce.id,
                description: ce.description ?? "",
                amount: ce.amount,
                category: ExpenseCategory(rawValue: ce.category) ?? .other,
                currency: Currency(rawValue: ce.currency ?? "JPY") ?? .JPY,
                paidByMemberId: ce.paidByMemberId,
                date: date,
                splitMemberIds: splitMemberIds,
                splits: splits,
                payerEarned: nil
            )
            expenses.append(exp)
        }
        let selectedMemberIds = memberIds.isEmpty ? [] : memberIds
        return LocalStorage.Snapshot(
            members: members,
            expenses: expenses,
            selectedMemberIds: selectedMemberIds,
            settledMemberIds: [],
            settlementPayments: [],
            paidExpenseMarks: paidExpenseMarks,
            settledExpenseIdsByPair: [:],
            events: []
        )
    }

    /// Upload local snapshot to cloud: create group, add members, add expenses. Returns the new groupId.
    func uploadLocalToCloud(snapshot: LocalStorage.Snapshot, groupName: String?) async throws -> String {
        let name = (groupName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "My Trip"
        let groupId = try await createGroup(name: name, description: nil)
        var localToCloudMemberId: [String: String] = [:]
        for m in snapshot.members {
            let cloudMember = try await addMember(groupId: groupId, name: m.name)
            localToCloudMemberId[m.id] = cloudMember.id
        }
        for e in snapshot.expenses {
            guard let paidByCloud = localToCloudMemberId[e.paidByMemberId] else { continue }
            let splits: [(memberId: String, amount: Double)] = e.splits.compactMap { mid, amount in
                guard let cloudId = localToCloudMemberId[mid] else { return nil }
                return (cloudId, amount)
            }
            guard !splits.isEmpty else { continue }
            _ = try await createExpense(
                groupId: groupId,
                description: e.description,
                amount: e.amount,
                currency: e.currency,
                category: e.category,
                paidByMemberId: paidByCloud,
                expenseDate: e.date,
                splits: splits
            )
        }
        return groupId
    }
}
