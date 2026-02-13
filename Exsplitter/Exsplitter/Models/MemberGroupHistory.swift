//
//  MemberGroupHistory.swift
//  Xsplitter
//
//  Saves member groups to history when resetting, so you can add a group back later.
//

import Combine
import Foundation
import SwiftUI

struct SavedMemberGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var label: String
    var memberNames: [String]
    var members: [Member]?
    var expenses: [Expense]?
    let savedAt: Date

    init(
        id: UUID = UUID(),
        label: String,
        memberNames: [String],
        members: [Member]? = nil,
        expenses: [Expense]? = nil,
        savedAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.memberNames = memberNames
        self.members = members
        self.expenses = expenses
        self.savedAt = savedAt
    }

    var shortDate: String {
        L10n.formatDate(savedAt)
    }

    /// Display names: from saved members if available, else memberNames.
    var displayMemberNames: [String] {
        if let m = members, !m.isEmpty { return m.map(\.name) }
        return memberNames
    }

    /// Name for a member id (from saved members snapshot).
    func memberName(id: String) -> String {
        members?.first(where: { $0.id == id })?.name ?? "—"
    }
}

final class MemberGroupHistoryStore: ObservableObject {
    static let shared = MemberGroupHistoryStore()

    private let key = "BudgetSplitter_memberGroupHistory"

    @Published private(set) var groups: [SavedMemberGroup] = []

    private init() {
        load()
    }

    /// Saves current group to history. Pass custom `label` (e.g. "Tokyo Trip") or nil for auto "Saved [date time]".
    func saveCurrentGroup(members: [Member], expenses: [Expense], label: String? = nil) {
        guard !members.isEmpty else { return }
        let memberNames = members.map(\.name)
        let finalLabel = (label?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? formatDefaultLabel()
        let group = SavedMemberGroup(
            label: finalLabel,
            memberNames: memberNames,
            members: members,
            expenses: expenses
        )
        groups.insert(group, at: 0)
        if groups.count > 20 {
            groups = Array(groups.prefix(20))
        }
        persist()
    }

    func updateGroupLabel(id: UUID, newLabel: String) {
        guard let i = groups.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        groups[i].label = trimmed
        persist()
    }

    func removeGroup(id: UUID) {
        groups.removeAll { $0.id == id }
        persist()
    }

    private func formatDefaultLabel() -> String {
        let lang = LanguageStore.shared.language
        let dateTime = L10n.formatDate(Date(), language: lang, dateStyle: .medium, timeStyle: .short)
        return "Saved \(dateTime)"
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SavedMemberGroup].self, from: data) else {
            groups = []
            return
        }
        groups = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
