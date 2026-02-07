//
//  BudgetDataStore.swift
//  BudgetSplitter
//

import Combine
import Foundation
import SwiftUI

/// Marks that a debtor has paid their share of this expense to the creditor (checkbox).
struct PaidExpenseMark: Codable, Hashable {
    let debtorId: String
    let creditorId: String
    let expenseId: String
}

/// A recorded payment from a debtor to a creditor (partial or full).
/// `amount` is the amount applied to the debt (counts toward "paid so far").
/// When they pay more than owed: `amountReceived` > `amount`, `changeGivenBack` = difference.
/// When they pay less: `amountTreatedByMe` = remaining shortfall you're waiving.
struct SettlementPayment: Identifiable, Codable, Hashable {
    var id: String
    var debtorId: String
    var creditorId: String
    var amount: Double
    var note: String?
    var date: Date
    /// Actual cash/transfer received (for display). If nil, treat as same as amount (backward compat).
    var amountReceived: Double?
    /// When they paid more than owed: change you gave back.
    var changeGivenBack: Double?
    /// When they paid less than owed: amount you're treating/waiving.
    var amountTreatedByMe: Double?
    /// Expense IDs this payment is for (nil = full/all expenses).
    var paymentForExpenseIds: [String]?
    
    init(id: String = UUID().uuidString, debtorId: String, creditorId: String, amount: Double, note: String? = nil, date: Date = Date(), amountReceived: Double? = nil, changeGivenBack: Double? = nil, amountTreatedByMe: Double? = nil, paymentForExpenseIds: [String]? = nil) {
        self.id = id
        self.debtorId = debtorId
        self.creditorId = creditorId
        self.amount = amount
        self.note = note
        self.date = date
        self.amountReceived = amountReceived
        self.changeGivenBack = changeGivenBack
        self.amountTreatedByMe = amountTreatedByMe
        self.paymentForExpenseIds = paymentForExpenseIds
    }
}

final class BudgetDataStore: ObservableObject {
    @Published var members: [Member] = []
    @Published var expenses: [Expense] = []
    @Published var events: [Event] = []
    /// When set, Expenses/Settle up (and optionally Overview) show only this trip's data. Set when user taps a trip on the homepage.
    @Published var selectedEvent: Event? = nil
    /// When true, the "Change trip" picker sheet is presented (from any tab).
    @Published var showTripPicker: Bool = false
    @Published var selectedMemberIds: Set<String> = []
    @Published var settledMemberIds: Set<String> = []
    @Published var settlementPayments: [SettlementPayment] = []
    @Published var paidExpenseMarks: [PaidExpenseMark] = []
    /// Expense IDs closed per (debtorId|creditorId). When "Mark as fully paid", we add current expense IDs so new expenses don't mix with old totals.
    @Published var settledExpenseIdsByPair: [String: Set<String>] = [:]
    
    private let membersKey = "BudgetSplitter_members"
    private let expensesKey = "BudgetSplitter_expenses"
    private let selectedKey = "BudgetSplitter_selected"
    private let settledKey = "BudgetSplitter_settled"
    private let settlementPaymentsKey = "BudgetSplitter_settlementPayments"
    private let paidExpenseMarksKey = "BudgetSplitter_paidExpenseMarks"
    
    /// Used only when adding from history; new users start with one member from "Who is the host?" flow.
    static let defaultMemberNames = [
        "Soon Zheng Dong", "Soon Cheng Wai", "Soon Xin Yi", "See Siew Pheng",
        "Ang Shin Nee", "See Siew Tin", "See Siew Kim", "See Eng Kim",
        "See Yi Joe", "Koay Jun Ming"
    ]
    
    init() {
        load()
        if members.isEmpty {
            // New user: leave members empty so app shows "Who is the host?" first.
        } else if selectedMemberIds.isEmpty {
            // Sync selected to all members if empty (e.g. fresh upgrade)
            selectedMemberIds = Set(members.map(\.id))
            save()
        }
    }
    
    /// Members to use in the UI: when a trip is selected, that trip's own members; otherwise global list (e.g. for trip list / new trip flow).
    func members(for eventId: String?) -> [Member] {
        guard let eid = eventId, let event = events.first(where: { $0.id == eid }) else {
            return members
        }
        return event.members
    }
    
    /// Add a member. When eventId is set (inside a trip), adds to that trip's members only. Otherwise adds to global list.
    func addMember(_ name: String, eventId: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let eid = eventId, let idx = events.firstIndex(where: { $0.id == eid }) {
            let member = Member(name: trimmed.isEmpty ? "Member 1" : trimmed, joinedAt: Date())
            events[idx].members.append(member)
            selectedMemberIds.insert(member.id)
            save()
            if selectedEvent?.id == eid {
                selectedEvent = events[idx]
            }
        } else {
            let member = Member(name: trimmed.isEmpty ? "Member 1" : trimmed, joinedAt: Date())
            members.append(member)
            selectedMemberIds.insert(member.id)
            save()
        }
    }
    
    /// Add a member at the beginning of the list (e.g. new host after previous host was removed).
    func addMemberAsFirst(_ name: String, eventId: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let eid = eventId, let idx = events.firstIndex(where: { $0.id == eid }) {
            let member = Member(name: trimmed.isEmpty ? "Member 1" : trimmed, joinedAt: Date())
            events[idx].members.insert(member, at: 0)
            selectedMemberIds.insert(member.id)
            save()
            if selectedEvent?.id == eid {
                selectedEvent = events[idx]
            }
        } else {
            let member = Member(name: trimmed.isEmpty ? "Member 1" : trimmed, joinedAt: Date())
            members.insert(member, at: 0)
            selectedMemberIds.insert(member.id)
            save()
        }
    }
    
    /// Remove a member. When eventId is set, removes from that trip's members only; otherwise from global list.
    func removeMember(id: String, eventId: String? = nil) {
        if let eid = eventId, let idx = events.firstIndex(where: { $0.id == eid }) {
            guard events[idx].members.count > 1 else { return }
            events[idx].members.removeAll { $0.id == id }
            selectedMemberIds.remove(id)
            let remainingFirstId = events[idx].members.first?.id
            expenses = expenses.compactMap { exp -> Expense? in
                guard exp.eventId == eid else { return exp }
                var e = exp
                e.splits.removeValue(forKey: id)
                e.splitMemberIds.removeAll { $0 == id }
                if e.paidByMemberId == id {
                    guard let first = remainingFirstId else { return nil }
                    e.paidByMemberId = first
                }
                if e.splitMemberIds.isEmpty { return nil }
                return e
            }
            settlementPayments.removeAll { $0.debtorId == id || $0.creditorId == id }
            paidExpenseMarks.removeAll { $0.debtorId == id || $0.creditorId == id }
            if selectedEvent?.id == eid {
                selectedEvent = events[idx]
            }
        } else {
            guard members.count > 1 else { return }
            members.removeAll { $0.id == id }
            selectedMemberIds.remove(id)
            let remainingFirstId = members.first?.id
            expenses = expenses.compactMap { exp -> Expense? in
                var e = exp
                e.splits.removeValue(forKey: id)
                e.splitMemberIds.removeAll { $0 == id }
                if e.paidByMemberId == id {
                    guard let first = remainingFirstId else { return nil }
                    e.paidByMemberId = first
                }
                if e.splitMemberIds.isEmpty { return nil }
                return e
            }
            settlementPayments.removeAll { $0.debtorId == id || $0.creditorId == id }
            paidExpenseMarks.removeAll { $0.debtorId == id || $0.creditorId == id }
        }
        save()
    }
    
    /// When a new expense is added, anyone in that expense’s split is no longer treated as "fully paid" so they can reappear in "Who owe me" if they have new debt.
    private func clearSettledForExpenseParticipants(_ expense: Expense) {
        var idsToClear = Set(expense.splitMemberIds)
        idsToClear.insert(expense.paidByMemberId)
        for id in idsToClear where !id.isEmpty {
            settledMemberIds.remove(id)
        }
    }
    
    /// Add expense. Saves to local SQLite.
    func addExpense(_ expense: Expense) {
        expenses.append(expense)
        clearSettledForExpenseParticipants(expense)
        save()
    }
    
    func deleteExpense(id: String) {
        expenses.removeAll { $0.id == id }
        save()
    }
    
    /// Clears all expenses and resets members to a single member (the host/first member). User must supply the name via UI.
    func resetAll(firstMemberName: String) {
        let name = firstMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        let first = Member(name: name.isEmpty ? "Member 1" : name, joinedAt: Date())
        members = [first]
        expenses = []
        events = []
        selectedMemberIds = [first.id]
        settledMemberIds = []
        settlementPayments = []
        paidExpenseMarks = []
        settledExpenseIdsByPair = [:]
        save()
    }

    // MARK: - Events (trips)

    /// Adds a new trip/event. Initial members are copied from global (by memberIds) so the new trip has its own unlinked member list.
    @discardableResult
    func addEvent(name: String, memberIds: [String]? = nil, currencyCodes: [String]? = nil, sessionType: SessionType = .trip, sessionTypeCustom: String? = nil) -> Event? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var initialMembers: [Member] = []
        if let ids = memberIds, !ids.isEmpty {
            initialMembers = ids.compactMap { id in members.first(where: { $0.id == id }) }
                .map { Member(name: $0.name, joinedAt: Date()) }
            assert(initialMembers.count == ids.count, "All memberIds should exist in global members")
        }
        let customTrimmed = sessionType == .other ? sessionTypeCustom?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        let custom = (customTrimmed?.isEmpty == false) ? customTrimmed : nil
        let event = Event(name: trimmed, memberIds: nil, currencyCodes: currencyCodes, members: initialMembers, sessionType: sessionType, sessionTypeCustom: custom)
        events.append(event)
        save()
        return event
    }

    func endEvent(id: String) {
        guard let idx = events.firstIndex(where: { $0.id == id }) else { return }
        events[idx].endedAt = Date()
        save()
    }

    /// Clears the current trip selection so the app shows the trip list (dashboard). Call from "Back to trips" button.
    /// Uses async dispatch so SwiftUI can finish the current gesture/update; otherwise when called from a non-Overview tab the UI may not switch to TripsHomeView (TabView observation quirk).
    func clearSelectedTrip() {
        #if DEBUG
        let before = selectedEvent?.name ?? "nil"
        print("[HomeBtn] clearSelectedTrip() called. selectedEvent before=\(before), dispatching to next run loop")
        #endif
        DispatchQueue.main.async { [weak self] in
            self?.selectedEvent = nil
            #if DEBUG
            print("[HomeBtn] selectedEvent set to nil (next run loop). now=\(self?.selectedEvent?.name ?? "nil")")
            #endif
        }
    }

    /// Removes a trip. Expenses that belonged to it become uncategorized (eventId set to nil). If this was the selected trip, selectedEvent is cleared.
    func removeEvent(id: String) {
        guard events.contains(where: { $0.id == id }) else { return }
        events.removeAll { $0.id == id }
        if selectedEvent?.id == id {
            selectedEvent = nil
        }
        expenses = expenses.map { exp in
            var e = exp
            if e.eventId == id { e.eventId = nil }
            return e
        }
        save()
    }

    /// Expenses that belong to the given event (nil = no event / uncategorized).
    func expenses(for eventId: String?) -> [Expense] {
        if let eid = eventId {
            return expenses.filter { $0.eventId == eid }
        }
        return expenses.filter { $0.eventId == nil }
    }

    /// Expenses for this event, filtered by event's member and currency rules when set.
    func filteredExpenses(for event: Event?) -> [Expense] {
        guard let event = event else { return expenses }
        var list = expenses.filter { $0.eventId == event.id }
        let participantIds: Set<String> = {
            if !event.members.isEmpty {
                return Set(event.members.map(\.id))
            }
            if let ids = event.memberIds, !ids.isEmpty {
                return Set(ids)
            }
            return Set()
        }()
        if !participantIds.isEmpty {
            list = list.filter { participantIds.contains($0.paidByMemberId) || $0.splitMemberIds.contains(where: { participantIds.contains($0) }) }
        }
        if let allowed = event.allowedCurrencies {
            list = list.filter { allowed.contains($0.currency) }
        }
        return list
    }

    /// Expense list for settle-up/balance when eventId is set (respects event's member and currency filters). When nil, returns all expenses.
    private func contextExpenses(for eventId: String?) -> [Expense] {
        guard let eid = eventId else { return expenses }
        if let event = events.first(where: { $0.id == eid }) {
            return filteredExpenses(for: event)
        }
        return expenses(for: eid)
    }

    /// Total spent for an event in a currency (sum of shares for selected members in that event's expenses). Respects event's member and currency filters.
    func totalSpent(for eventId: String?, currency: Currency) -> Double {
        let event = eventId.flatMap { eid in events.first(where: { $0.id == eid }) }
        let list = event.map { filteredExpenses(for: $0) } ?? expenses(for: eventId)
        return list
            .filter { $0.currency == currency }
            .reduce(0) { sum, exp in
                sum + exp.splits
                    .filter { selectedMemberIds.contains($0.key) }
                    .values
                    .reduce(0, +)
            }
    }

    /// Whether all debts for this event's expenses are settled (uses event's member/currency filters).
    func isEventSettled(eventId: String) -> Bool {
        let event = events.first(where: { $0.id == eventId })
        let eventExpenses = event.map { filteredExpenses(for: $0) } ?? expenses(for: eventId)
        guard !eventExpenses.isEmpty else { return true }
        let memberIds = Set(eventExpenses.flatMap { [$0.paidByMemberId] + $0.splitMemberIds })
        var balances: [String: Double] = [:]
        for mid in memberIds {
            let paid = eventExpenses
                .filter { $0.currency == .JPY && $0.paidByMemberId == mid }
                .reduce(0) { $0 + ($1.amount - ($1.payerEarned ?? 0)) }
            let share = eventExpenses
                .compactMap { $0.splits[mid] }
                .reduce(0, +)
            balances[mid] = paid - share
        }
        let nonzero = balances.filter { abs($0.value) > 0.001 }
        return nonzero.isEmpty
    }

    /// Adds all names as new members (e.g. from a saved group in history). The host (first member) is never removed.
    func addMembersFromHistory(names: [String]) {
        let trimmedNames = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !trimmedNames.isEmpty else { return }
        for name in trimmedNames {
            addMember(name)
        }
    }
    
    func toggleSelected(memberId: String) {
        if selectedMemberIds.contains(memberId) {
            selectedMemberIds.remove(memberId)
        } else {
            selectedMemberIds.insert(memberId)
        }
        save()
    }
    
    func toggleSettled(memberId: String) {
        if settledMemberIds.contains(memberId) {
            settledMemberIds.remove(memberId)
        } else {
            settledMemberIds.insert(memberId)
        }
        save()
    }
    
    /// Mark debtor as fully paid to creditor and record current expense IDs so future totals only include new expenses. "Add up" without resetting.
    func markFullyPaid(debtorId: String, creditorId: String) {
        let key = pairKey(debtorId: debtorId, creditorId: creditorId)
        let currentIds = Set(Currency.allCases.flatMap { expensesContributingToDebt(creditorId: creditorId, debtorId: debtorId, currency: $0).map(\.expense.id) })
        var existing = settledExpenseIdsByPair[key] ?? []
        existing.formUnion(currentIds)
        settledExpenseIdsByPair[key] = existing
        settledMemberIds.insert(debtorId)
        save()
    }
    
    private func pairKey(debtorId: String, creditorId: String) -> String {
        "\(debtorId)|\(creditorId)"
    }
    
    /// Expense IDs already settled for this (debtor, creditor). Exclude these from "total owed" so new expenses show separately.
    func settledExpenseIds(debtorId: String, creditorId: String) -> Set<String> {
        Set(settledExpenseIdsByPair[pairKey(debtorId: debtorId, creditorId: creditorId)] ?? [])
    }
    
    /// Expenses contributing to debt for this pair, excluding ones already settled. Optional eventId filters to that trip.
    func activeExpensesContributingToDebt(creditorId: String, debtorId: String, currency: Currency = .JPY, eventId: String? = nil) -> [(expense: Expense, share: Double)] {
        let settled = settledExpenseIds(debtorId: debtorId, creditorId: creditorId)
        return expensesContributingToDebt(creditorId: creditorId, debtorId: debtorId, currency: currency, eventId: eventId)
            .filter { !settled.contains($0.expense.id) }
    }
    
    /// Amount debtor owes creditor in this currency from active (non-settled) expenses only. Optional eventId filters to that trip.
    func amountOwedActiveOnly(from debtorId: String, to creditorId: String, currency: Currency = .JPY, eventId: String? = nil) -> Double {
        activeExpensesContributingToDebt(creditorId: creditorId, debtorId: debtorId, currency: currency, eventId: eventId)
            .reduce(0) { $0 + $1.share }
    }
    
    // MARK: - Settle up
    
    /// Total this member paid (as payer) in the given currency. Optional eventId uses event's member/currency filters.
    func totalPaidBy(memberId: String, currency: Currency, eventId: String? = nil) -> Double {
        let list = contextExpenses(for: eventId)
        return list
            .filter { $0.currency == currency && $0.paidByMemberId == memberId }
            .reduce(0) { $0 + ($1.amount - ($1.payerEarned ?? 0)) }
    }
    
    /// Total share for this member in the given currency (from splits). Optional eventId uses event's member/currency filters.
    func totalShare(memberId: String, currency: Currency, eventId: String? = nil) -> Double {
        let list = contextExpenses(for: eventId)
        return list
            .filter { $0.currency == currency }
            .compactMap { $0.splits[memberId] }
            .reduce(0, +)
    }
    
    /// Net balance: positive = owed money, negative = owes money. Optional eventId filters to that trip.
    func netBalance(memberId: String, currency: Currency, eventId: String? = nil) -> Double {
        totalPaidBy(memberId: memberId, currency: currency, eventId: eventId) - totalShare(memberId: memberId, currency: currency, eventId: eventId)
    }
    
    /// Minimal transfers to settle up: (debtorId, creditorId, amount). Optional eventId uses event's member/currency filters. Uses all members who actually participate in the event's expenses (payer or in split) so settle-up always shows who owes whom.
    func settlementTransfers(currency: Currency, eventId: String? = nil) -> [(from: String, to: String, amount: Double)] {
        let event = eventId.flatMap { eid in events.first(where: { $0.id == eid }) }
        let list = contextExpenses(for: eventId)
        let participantIds = Set(list.flatMap { [$0.paidByMemberId] + $0.splitMemberIds })
        let membersToUse: [Member] = {
            if let ev = event, !ev.members.isEmpty {
                return ev.members.filter { participantIds.isEmpty || participantIds.contains($0.id) }
            }
            if participantIds.isEmpty {
                if let ids = event?.memberIds, !ids.isEmpty {
                    return members.filter { ids.contains($0.id) }
                }
                return members
            }
            return members.filter { participantIds.contains($0.id) }
        }()
        var balances: [String: Double] = [:]
        for m in membersToUse {
            let b = netBalance(memberId: m.id, currency: currency, eventId: eventId)
            if abs(b) > 0.001 { balances[m.id] = b }
        }
        var result: [(from: String, to: String, amount: Double)] = []
        var debtors = balances.filter { $0.value < -0.001 }.map { ($0.key, -$0.value) }.sorted { $0.1 > $1.1 }
        var creditors = balances.filter { $0.value > 0.001 }.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
        var i = 0, j = 0
        while i < debtors.count, j < creditors.count {
            let (debtor, dAmt) = debtors[i]
            let (creditor, cAmt) = creditors[j]
            let transfer = min(dAmt, cAmt)
            if transfer > 0.001 {
                result.append((from: debtor, to: creditor, amount: transfer))
            }
            if dAmt - transfer < 0.001 { i += 1 } else { debtors[i] = (debtor, dAmt - transfer) }
            if cAmt - transfer < 0.001 { j += 1 } else { creditors[j] = (creditor, cAmt - transfer) }
        }
        return result
    }
    
    /// Amount debtor owes creditor (from settlement transfers). Optional eventId filters to that trip.
    func amountOwed(from debtorId: String, to creditorId: String, currency: Currency = .JPY, eventId: String? = nil) -> Double {
        settlementTransfers(currency: currency, eventId: eventId)
            .filter { $0.from == debtorId && $0.to == creditorId }
            .reduce(0) { $0 + $1.amount }
    }
    
    /// Total amount recorded as paid from debtor to creditor.
    func totalPaidFromTo(debtorId: String, creditorId: String) -> Double {
        settlementPayments
            .filter { $0.debtorId == debtorId && $0.creditorId == creditorId }
            .reduce(0) { $0 + $1.amount }
    }
    
    /// Amount from recorded payments allocated to this expense. When a payment is for multiple expenses (paymentForExpenseIds has >1 id), the payment amount is split across them so the total is counted once, not per expense.
    func amountPaidTowardExpense(debtorId: String, creditorId: String, expenseId: String) -> Double {
        var total: Double = 0
        for payment in settlementPayments where payment.debtorId == debtorId && payment.creditorId == creditorId {
            guard let ids = payment.paymentForExpenseIds, !ids.isEmpty, ids.contains(expenseId) else { continue }
            if ids.count == 1 {
                total += payment.amount
            } else {
                total += payment.amount / Double(ids.count)
            }
        }
        return total
    }
    
    /// Sum of payment amounts that are not allocated to any specific expense. Counted toward "paid so far" for this debtor–creditor pair (including when viewing a trip).
    func unallocatedPaymentTotal(debtorId: String, creditorId: String, eventId: String? = nil) -> Double {
        return settlementPayments
            .filter { $0.debtorId == debtorId && $0.creditorId == creditorId }
            .filter { ($0.paymentForExpenseIds ?? []).isEmpty }
            .reduce(0) { $0 + $1.amount }
    }
    
    /// All payment records from debtor to creditor.
    func paymentsFromTo(debtorId: String, creditorId: String) -> [SettlementPayment] {
        settlementPayments
            .filter { $0.debtorId == debtorId && $0.creditorId == creditorId }
            .sorted { $0.date < $1.date }
    }
    
    func addSettlementPayment(debtorId: String, creditorId: String, amount: Double, note: String? = nil, amountReceived: Double? = nil, changeGivenBack: Double? = nil, amountTreatedByMe: Double? = nil, paymentForExpenseIds: [String]? = nil) {
        settlementPayments.append(SettlementPayment(debtorId: debtorId, creditorId: creditorId, amount: amount, note: note, amountReceived: amountReceived, changeGivenBack: changeGivenBack, amountTreatedByMe: amountTreatedByMe, paymentForExpenseIds: paymentForExpenseIds))
        save()
    }
    
    /// Expenses where creditor paid and debtor had a share. Optional eventId uses event's member/currency filters.
    func expensesContributingToDebt(creditorId: String, debtorId: String, currency: Currency = .JPY, eventId: String? = nil) -> [(expense: Expense, share: Double)] {
        let list = contextExpenses(for: eventId)
        return list
            .filter { $0.currency == currency && $0.paidByMemberId == creditorId }
            .compactMap { exp -> (Expense, Double)? in
                guard let share = exp.splits[debtorId], share > 0 else { return nil }
                return (exp, share)
            }
    }
    
    /// Whether this expense is marked as paid (checkbox) by debtor to creditor.
    func isExpensePaid(debtorId: String, creditorId: String, expenseId: String) -> Bool {
        paidExpenseMarks.contains { $0.debtorId == debtorId && $0.creditorId == creditorId && $0.expenseId == expenseId }
    }
    
    /// Toggle expense paid checkbox for (debtor, creditor).
    func toggleExpensePaid(debtorId: String, creditorId: String, expenseId: String) {
        if isExpensePaid(debtorId: debtorId, creditorId: creditorId, expenseId: expenseId) {
            paidExpenseMarks.removeAll { $0.debtorId == debtorId && $0.creditorId == creditorId && $0.expenseId == expenseId }
        } else {
            paidExpenseMarks.append(PaidExpenseMark(debtorId: debtorId, creditorId: creditorId, expenseId: expenseId))
        }
        save()
    }
    
    /// Total amount counted as paid via expense checkboxes for this (debtor, creditor).
    func totalPaidViaExpenseCheckboxes(debtorId: String, creditorId: String, currency: Currency = .JPY) -> Double {
        let breakdown = expensesContributingToDebt(creditorId: creditorId, debtorId: debtorId, currency: currency)
        return breakdown
            .filter { isExpensePaid(debtorId: debtorId, creditorId: creditorId, expenseId: $0.expense.id) }
            .reduce(0) { $0 + $1.share }
    }
    
    // MARK: - Computed
    
    var totalSpentByCurrency: [Currency: Double] {
        var result: [Currency: Double] = [:]
        for exp in expenses {
            let selectedShare = exp.splits
                .filter { selectedMemberIds.contains($0.key) }
                .values
                .reduce(0, +)
            if selectedShare > 0 {
                result[exp.currency, default: 0] += selectedShare
            }
        }
        return result
    }
    
    var totalExpenseCount: Int { expenses.count }
    
    func totalSpent(currency: Currency) -> Double {
        totalSpentByCurrency[currency] ?? 0
    }
    
    func memberTotal(memberId: String, currency: Currency) -> Double {
        expenses
            .filter { $0.currency == currency }
            .compactMap { $0.splits[memberId] }
            .reduce(0, +)
    }
    
    func categoryTotals(currency: Currency) -> [ExpenseCategory: Double] {
        var result: [ExpenseCategory: Double] = [:]
        for exp in expenses where exp.currency == currency {
            let selectedShare = exp.splits
                .filter { selectedMemberIds.contains($0.key) }
                .values
                .reduce(0, +)
            if selectedShare > 0 {
                result[exp.category, default: 0] += selectedShare
            }
        }
        return result
    }
    
    /// Category totals for a single member (their share per category).
    func categoryTotals(memberId: String, currency: Currency) -> [ExpenseCategory: Double] {
        var result: [ExpenseCategory: Double] = [:]
        for exp in expenses where exp.currency == currency {
            if let share = exp.splits[memberId], share > 0 {
                result[exp.category, default: 0] += share
            }
        }
        return result
    }

    /// Category totals for multiple members combined.
    func categoryTotals(memberIds: Set<String>, currency: Currency) -> [ExpenseCategory: Double] {
        var result: [ExpenseCategory: Double] = [:]
        for id in memberIds {
            let cat = categoryTotals(memberId: id, currency: currency)
            for (k, v) in cat {
                result[k, default: 0] += v
            }
        }
        return result
    }

    /// Total spent by the given members combined.
    func totalSpent(memberIds: Set<String>, currency: Currency) -> Double {
        memberIds.reduce(0) { $0 + memberTotal(memberId: $1, currency: currency) }
    }
    
    // MARK: - Persistence
    
    private func load() {
        let snapshot = LocalStorage.shared.loadAll()
        members = snapshot.members
        expenses = snapshot.expenses
        events = snapshot.events
        selectedMemberIds = snapshot.selectedMemberIds
        settledMemberIds = snapshot.settledMemberIds
        settlementPayments = snapshot.settlementPayments
        paidExpenseMarks = snapshot.paidExpenseMarks
        settledExpenseIdsByPair = snapshot.settledExpenseIdsByPair.mapValues { Set($0) }
    }
    
    private func save() {
        LocalStorage.shared.saveAll(
            members: members,
            expenses: expenses,
            selectedMemberIds: selectedMemberIds,
            settledMemberIds: settledMemberIds,
            settlementPayments: settlementPayments,
            paidExpenseMarks: paidExpenseMarks,
            settledExpenseIdsByPair: Dictionary(uniqueKeysWithValues: settledExpenseIdsByPair.map { ($0.key, Array($0.value)) }),
            events: events
        )
    }
}
