//
//  SettleUpView.swift
//  Exsplitter
//
//  Who owes whom and who's paid (checkboxes).
//

import SwiftUI

struct SettleUpView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @ObservedObject private var currencyStore = CurrencyStore.shared
    @ObservedObject private var languageStore = LanguageStore.shared
    /// When set, back button goes to Overview tab; when nil, goes to trip dashboard.
    var onBackToOverview: (() -> Void)? = nil
    @State private var selectedMemberId: String = ""
    @State private var settlementCurrency: Currency = CurrencyStore.shared.preferredCurrency
    @State private var selectedDebtorForDetail: String? = nil
    
    private func formatMoney(_ amount: Double, _ currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = currency.decimals
        formatter.minimumFractionDigits = currency.decimals
        let str = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "\(currency.symbol)\(str)"
    }
    
    /// Members for the current trip (or global when no trip). Settle-up "view as" and balances use this list.
    private var settleMembers: [Member] { dataStore.members(for: dataStore.selectedEvent?.id) }
    
    private func memberName(id: String) -> String {
        settleMembers.first(where: { $0.id == id })?.name ?? "—"
    }
    
    /// When set, settle-up shows only this trip's debts/balances.
    private var eventId: String? { dataStore.selectedEvent?.id }
    
    /// All (from, to) pairs that appear in any currency's settlement.
    private var allTransferPairs: [(from: String, to: String)] {
        var pairs: [(from: String, to: String)] = []
        var seen = Set<String>()
        for c in Currency.allCases {
            for t in dataStore.settlementTransfers(currency: c, eventId: eventId) {
                let key = "\(t.from)|\(t.to)"
                if !seen.contains(key) {
                    seen.insert(key)
                    pairs.append((t.from, t.to))
                }
            }
        }
        return pairs
    }
    
    /// Amount owed from debtor to creditor in settlement currency (active/non-settled expenses only).
    private func amountOwedInCurrency(from: String, to: String, in target: Currency) -> Double {
        Currency.allCases.reduce(0) { sum, c in
            sum + dataStore.amountOwedActiveOnly(from: from, to: to, currency: c, eventId: eventId) * currencyStore.rate(from: c, to: target)
        }
    }
    
    /// Total paid from debtor to creditor in settlement terms (active expenses only).
    private func totalPaidInSettlement(from debtorId: String, to creditorId: String) -> Double {
        let totalOwed = amountOwedInCurrency(from: debtorId, to: creditorId, in: settlementCurrency)
        if dataStore.settledMemberIds.contains(debtorId) {
            return totalOwed
        }
        let unallocated = dataStore.unallocatedPaymentTotal(debtorId: debtorId, creditorId: creditorId, eventId: eventId)
        let expenseBreakdownInSettlement: [(expense: Expense, share: Double)] = Currency.allCases.flatMap { c in
            dataStore.activeExpensesContributingToDebt(creditorId: creditorId, debtorId: debtorId, currency: c, eventId: eventId)
                .map { (expense: $0.expense, share: $0.share * currencyStore.rate(from: c, to: settlementCurrency)) }
        }
        let perExpenseTotal = expenseBreakdownInSettlement.reduce(0.0) { sum, item in
            let paidToward = dataStore.amountPaidTowardExpense(debtorId: debtorId, creditorId: creditorId, expenseId: item.expense.id)
            let isTicked = dataStore.isExpensePaid(debtorId: debtorId, creditorId: creditorId, expenseId: item.expense.id)
            let counted = isTicked ? item.share : paidToward
            return sum + counted
        }
        return unallocated + perExpenseTotal
    }
    
    /// Transfers in settlement currency (who owes whom, converted so creditor can choose MYR or Yen etc).
    private var transfersInSettlement: [(from: String, to: String, amount: Double)] {
        allTransferPairs
            .map { (from: $0.from, to: $0.to, amount: amountOwedInCurrency(from: $0.from, to: $0.to, in: settlementCurrency)) }
            .filter { $0.amount > 0.001 }
    }
    
    /// Transfers where the selected member still owes (I need to pay). Only includes when stillOwed > 0. Sorted alphabetically by creditor name.
    private var iNeedToPay: [(to: String, totalOwed: Double, stillOwed: Double)] {
        let list = transfersInSettlement
            .filter { $0.from == selectedMemberId }
            .map { pair in
                let paid = totalPaidInSettlement(from: pair.from, to: pair.to)
                let still = max(0, pair.amount - paid)
                return (to: pair.to, totalOwed: pair.amount, stillOwed: still)
            }
            .filter { $0.stillOwed > 0.001 }
        return list.sorted { memberName(id: $0.to).localizedCaseInsensitiveCompare(memberName(id: $1.to)) == .orderedAscending }
    }
    
    /// Transfers where others still owe the selected member (Who owe me). Excludes when stillOwed <= 0 or when marked as fully paid (settled). Sorted alphabetically by debtor name.
    private var whoOweMe: [(from: String, amount: Double)] {
        let list = transfersInSettlement
            .filter { $0.to == selectedMemberId }
            .filter { pair in
                if dataStore.settledMemberIds.contains(pair.from) { return false }
                let paid = totalPaidInSettlement(from: pair.from, to: selectedMemberId)
                let still = max(0, pair.amount - paid)
                return still > 0.001
            }
            .map { (from: $0.from, amount: $0.amount) }
        return list.sorted { memberName(id: $0.from).localizedCaseInsensitiveCompare(memberName(id: $1.from)) == .orderedAscending }
    }
    
    /// People who owed me and have fully paid (for "Who's paid?" section). Includes marked settled or stillOwed <= 0. Sorted alphabetically by debtor name.
    private var whoPaidMe: [(from: String, amount: Double)] {
        let list = transfersInSettlement
            .filter { $0.to == selectedMemberId }
            .filter { pair in
                let paid = totalPaidInSettlement(from: pair.from, to: selectedMemberId)
                let still = max(0, pair.amount - paid)
                return still <= 0.001 || dataStore.settledMemberIds.contains(pair.from)
            }
            .map { (from: $0.from, amount: $0.amount) }
        return list.sorted { memberName(id: $0.from).localizedCaseInsensitiveCompare(memberName(id: $1.from)) == .orderedAscending }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if dataStore.expenses.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text(L10n.string("settle.noExpensesYet", language: languageStore.language))
                                .font(.headline)
                                .foregroundColor(.appPrimary)
                            Text(L10n.string("settle.addExpensesFirst", language: languageStore.language))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                    } else {
                        // Who am I — see balances as this person
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("settle.viewAs", language: languageStore.language))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Menu {
                                ForEach(settleMembers) { member in
                                    Button(member.name) {
                                        selectedMemberId = member.id
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(memberName(id: selectedMemberId))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.appPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(Color.appTertiary)
                                .cornerRadius(8)
                            }
                            .onAppear {
                                if selectedMemberId.isEmpty, let first = settleMembers.first {
                                    selectedMemberId = first.id
                                }
                            }
                            .onChange(of: dataStore.selectedEvent?.id) { _, _ in
                                let members = settleMembers
                                if selectedMemberId.isEmpty, let first = members.first {
                                    selectedMemberId = first.id
                                } else if !members.contains(where: { $0.id == selectedMemberId }), let first = members.first {
                                    selectedMemberId = first.id
                                }
                            }
                            .onChange(of: settleMembers.count) { _, _ in
                                let members = settleMembers
                                if selectedMemberId.isEmpty, let first = members.first {
                                    selectedMemberId = first.id
                                } else if !members.contains(where: { $0.id == selectedMemberId }), let first = members.first {
                                    selectedMemberId = first.id
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appCard)
                        .cornerRadius(12)
                        
                        // Settle in: choose currency (MYR, Yen, etc.) so who owes who is shown in one currency
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("settle.settleIn", language: languageStore.language))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Menu {
                                ForEach(Currency.allCases, id: \.self) { c in
                                    Button("\(c.symbol) \(c.rawValue)") {
                                        settlementCurrency = c
                                    }
                                }
                            } label: {
                                HStack {
                                    Text("\(settlementCurrency.symbol) \(settlementCurrency.rawValue)")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.appPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(Color.appTertiary)
                                .cornerRadius(8)
                            }
                            .onAppear {
                                settlementCurrency = currencyStore.preferredCurrency
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appCard)
                        .cornerRadius(12)
                        
                        // I need to pay (you owe)
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.string("settle.iNeedToPay", language: languageStore.language))
                                .font(.headline.bold())
                                .foregroundColor(.appPrimary)
                            Text(L10n.string("settle.youOweThese", language: languageStore.language).replacingOccurrences(of: "%@", with: settlementCurrency.rawValue))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if iNeedToPay.isEmpty {
                                Text(L10n.string("settle.nothingToPay", language: languageStore.language))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(iNeedToPay, id: \.to) { t in
                                    HStack {
                                        Text(L10n.string("settle.youOwe", language: languageStore.language).replacingOccurrences(of: "%@", with: memberName(id: t.to)))
                                            .font(.subheadline)
                                            .foregroundColor(.appPrimary)
                                        Spacer()
                                        Text("\(L10n.string("settle.stillOwes", language: languageStore.language)) \(formatMoney(t.stillOwed, settlementCurrency))")
                                            .font(.subheadline.bold())
                                            .foregroundColor(.orange)
                                            .monospacedDigit()
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.appTertiary)
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appCard)
                        .cornerRadius(12)
                        
                        // Who owe me
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.string("settle.whoOweMe", language: languageStore.language))
                                .font(.headline.bold())
                                .foregroundColor(.appPrimary)
                            Text(L10n.string("settle.thesePeopleOweYou", language: languageStore.language).replacingOccurrences(of: "%@", with: settlementCurrency.rawValue))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if whoOweMe.isEmpty {
                                Text(L10n.string("settle.noOneOwesYou", language: languageStore.language))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(whoOweMe, id: \.from) { t in
                                    Button {
                                        selectedDebtorForDetail = t.from
                                    } label: {
                                        HStack {
                                            Text(L10n.string("settle.owesYou", language: languageStore.language).replacingOccurrences(of: "%@", with: memberName(id: t.from)))
                                                .font(.subheadline)
                                                .foregroundColor(.appPrimary)
                                            Spacer()
                                            let paid = totalPaidInSettlement(from: t.from, to: selectedMemberId)
                                            let still = max(0, t.amount - paid)
                                            Text(still > 0 ? "\(L10n.string("settle.stillOwes", language: languageStore.language)) \(formatMoney(still, settlementCurrency))" : formatMoney(t.amount, settlementCurrency))
                                                .font(.subheadline.bold())
                                                .foregroundColor(still > 0 ? .orange : .green)
                                                .monospacedDigit()
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(Color.appTertiary)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appCard)
                        .cornerRadius(12)
                        
                        // Who's paid you back — tap to see details
                        if !whoPaidMe.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(L10n.string("settle.whosPaid", language: languageStore.language))
                                    .font(.headline.bold())
                                    .foregroundColor(.appPrimary)
                                ForEach(whoPaidMe, id: \.from) { t in
                                    Button {
                                        selectedDebtorForDetail = t.from
                                    } label: {
                                        HStack {
                                            Text(memberName(id: t.from))
                                                .font(.subheadline)
                                                .foregroundColor(.appPrimary)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(Color.appTertiary)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.appCard)
                            .cornerRadius(12)
                        }
                        
                    }
                }
                .padding()
            }
            .id(dataStore.expenses.count)
            .background(Color.appBackground)
            .navigationTitle(dataStore.selectedEvent?.name ?? L10n.string("settle.title", language: languageStore.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if dataStore.selectedEvent != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        BackToTripsButton(onGoToOverview: onBackToOverview)
                            .environmentObject(dataStore)
                    }
                }
            }
            .sheet(item: Binding(
                get: { selectedDebtorForDetail.map { DebtorDetailItem(debtorId: $0) } },
                set: { selectedDebtorForDetail = $0?.debtorId }
            )) { item in
                SettleUpDebtorDetailSheet(
                    debtorId: item.debtorId,
                    creditorId: selectedMemberId,
                    settlementCurrency: settlementCurrency,
                    dataStore: dataStore,
                    formatMoney: formatMoney,
                    memberName: memberName,
                    language: languageStore.language,
                    onDismiss: { selectedDebtorForDetail = nil }
                )
            }
        }
    }
}

private struct DebtorDetailItem: Identifiable {
    let debtorId: String
    var id: String { debtorId }
}

// MARK: - Debtor detail sheet (expense breakdown, payments, still owes, mark paid)
struct SettleUpDebtorDetailSheet: View {
    let debtorId: String
    let creditorId: String
    let settlementCurrency: Currency
    @ObservedObject var dataStore: BudgetDataStore
    @ObservedObject private var currencyStore = CurrencyStore.shared
    let formatMoney: (Double, Currency) -> String
    let memberName: (String) -> String
    let language: AppLanguage
    let onDismiss: () -> Void
    
    private var eventId: String? { dataStore.selectedEvent?.id }
    
    /// Total owed in settlement currency (active/non-settled expenses only).
    private var totalOwed: Double {
        Currency.allCases.reduce(0) { sum, c in
            sum + dataStore.amountOwedActiveOnly(from: debtorId, to: creditorId, currency: c, eventId: eventId) * currencyStore.rate(from: c, to: settlementCurrency)
        }
    }
    
    /// Total paid: unallocated + per-expense (ticked ? full share : amount paid toward). Uses all contributing expenses (including settled) so the total stays correct after "Fully paid".
    private var totalPaid: Double {
        let unallocated = dataStore.unallocatedPaymentTotal(debtorId: debtorId, creditorId: creditorId, eventId: eventId)
        let perExpenseTotal = allExpensesContributingToDebt.reduce(0.0) { sum, item in
            let paidToward = dataStore.amountPaidTowardExpense(debtorId: debtorId, creditorId: creditorId, expenseId: item.expense.id)
            let isTicked = dataStore.isExpensePaid(debtorId: debtorId, creditorId: creditorId, expenseId: item.expense.id)
            let counted = isTicked ? item.share : paidToward
            return sum + counted
        }
        return unallocated + perExpenseTotal
    }
    
    private var stillOwed: Double {
        max(0, totalOwed - totalPaid)
    }
    
    private var isMarkedSettled: Bool {
        dataStore.settledMemberIds.contains(debtorId)
    }
    
    /// Active (non-settled) expenses contributing to debt with share in settlement currency.
    private var expenseBreakdown: [(expense: Expense, share: Double)] {
        Currency.allCases.flatMap { c in
            dataStore.activeExpensesContributingToDebt(creditorId: creditorId, debtorId: debtorId, currency: c, eventId: eventId)
                .map { (expense: $0.expense, share: $0.share * currencyStore.rate(from: c, to: settlementCurrency)) }
        }
    }
    
    /// All expenses contributing to debt (including settled), with share in settlement currency. Used so "Payments received" stays visible after "Fully paid".
    private var allExpensesContributingToDebt: [(expense: Expense, share: Double)] {
        Currency.allCases.flatMap { c in
            dataStore.expensesContributingToDebt(creditorId: creditorId, debtorId: debtorId, currency: c, eventId: eventId)
                .map { (expense: $0.expense, share: $0.share * currencyStore.rate(from: c, to: settlementCurrency)) }
        }
    }
    
    private var payments: [SettlementPayment] {
        dataStore.paymentsFromTo(debtorId: debtorId, creditorId: creditorId)
    }
    
    /// Expenses marked as paid (for "Payments received"). Uses all contributing expenses (including settled) so the list does not disappear after "Fully paid".
    private var paidExpensesFromCheckboxes: [(expense: Expense, share: Double)] {
        allExpensesContributingToDebt.filter { dataStore.isExpensePaid(debtorId: debtorId, creditorId: creditorId, expenseId: $0.expense.id) }
    }
    
    /// Total change given back across all payments (when they paid more than owed).
    private var totalChangeGivenBack: Double {
        payments.reduce(0) { $0 + ($1.changeGivenBack ?? 0) }
    }
    
    /// Total amount treated by you across all payments (when they paid less and you marked/considered paid).
    private var totalAmountTreatedByMe: Double {
        payments.reduce(0) { $0 + ($1.amountTreatedByMe ?? 0) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Summary: what they owe, what's paid, still owes or fully returned
                    VStack(alignment: .leading, spacing: 10) {
                        if stillOwed > 0 && !isMarkedSettled {
                            Text(L10n.string("settle.stillOwes", language: language))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatMoney(stillOwed, settlementCurrency))
                                .font(.title2.bold())
                                .foregroundColor(.orange)
                                .monospacedDigit()
                        }
                        HStack {
                            Text(L10n.string("settle.totalOwedToYou", language: language))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatMoney(totalOwed, settlementCurrency))
                                .font(.subheadline.bold())
                                .foregroundColor(.appPrimary)
                                .monospacedDigit()
                        }
                        HStack {
                            Text(L10n.string("settle.paidSoFar", language: language))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatMoney(totalPaid, settlementCurrency))
                                .font(.subheadline.bold())
                                .foregroundColor(.green)
                                .monospacedDigit()
                        }
                        if stillOwed <= 0.001 || isMarkedSettled {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(L10n.string("settle.fullyReturned", language: language))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.green)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appCard)
                    .cornerRadius(12)
                    
                    // What they owe for — tick when they've paid you for that item
                    if !expenseBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("settle.fromTheseExpenses", language: language))
                                .font(.headline.bold())
                                .foregroundColor(.appPrimary)
                            ForEach(expenseBreakdown, id: \.expense.id) { item in
                                let isPaid = dataStore.isExpensePaid(debtorId: debtorId, creditorId: creditorId, expenseId: item.expense.id)
                                let paidToward = dataStore.amountPaidTowardExpense(debtorId: debtorId, creditorId: creditorId, expenseId: item.expense.id)
                                let leftToPay = max(0, item.share - paidToward)
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.expense.description.isEmpty ? "Expense" : item.expense.description)
                                            .font(.subheadline)
                                            .foregroundColor(.appPrimary)
                                            .lineLimit(1)
                                            .strikethrough(isPaid, color: .secondary)
                                        if !isPaid, leftToPay > 0.001, paidToward > 0 {
                                            Text(L10n.string("settle.leftToPay", language: language).replacingOccurrences(of: "%@", with: formatMoney(leftToPay, settlementCurrency)))
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    Spacer()
                                    Text(formatMoney(item.share, settlementCurrency))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                        .strikethrough(isPaid, color: .secondary)
                                    Toggle("", isOn: Binding(
                                        get: { dataStore.isExpensePaid(debtorId: debtorId, creditorId: creditorId, expenseId: item.expense.id) },
                                        set: { _ in dataStore.toggleExpensePaid(debtorId: debtorId, creditorId: creditorId, expenseId: item.expense.id) }
                                    ))
                                    .labelsHidden()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color.appTertiary)
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appCard)
                        .cornerRadius(12)
                    }
                    
                    // Recorded payments (what they paid) + expenses already ticked as paid
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("settle.paymentsReceived", language: language))
                            .font(.headline.bold())
                            .foregroundColor(.appPrimary)
                        if !paidExpensesFromCheckboxes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.string("settle.fromThesePaid", language: language))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(paidExpensesFromCheckboxes, id: \.expense.id) { item in
                                    let paidToward = dataStore.amountPaidTowardExpense(debtorId: debtorId, creditorId: creditorId, expenseId: item.expense.id)
                                    let remainderPaidByTick = max(0, item.share - paidToward)
                                    let name = item.expense.description.isEmpty ? item.expense.category.rawValue : item.expense.description
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(name)
                                                .font(.subheadline)
                                                .foregroundColor(.appPrimary)
                                                .lineLimit(1)
                                            if paidToward > 0.001 && remainderPaidByTick > 0.001 {
                                                Text(L10n.string("settle.alsoPaid", language: language).replacingOccurrences(of: "%@", with: formatMoney(remainderPaidByTick, settlementCurrency)))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Text(formatMoney(remainderPaidByTick > 0 ? remainderPaidByTick : item.share, settlementCurrency))
                                            .font(.subheadline)
                                            .foregroundColor(.green)
                                            .monospacedDigit()
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 12)
                                    .background(Color.appTertiary)
                                    .cornerRadius(8)
                                }
                            }
                        }
                        if payments.isEmpty && paidExpensesFromCheckboxes.isEmpty {
                            Text(L10n.string("settle.noPaymentsRecorded", language: language))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        }
                        if !payments.isEmpty {
                            ForEach(payments) { p in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(formatMoney(p.amountReceived ?? p.amount, settlementCurrency))
                                            .font(.subheadline.bold())
                                            .foregroundColor(.green)
                                            .monospacedDigit()
                                        if let change = p.changeGivenBack, change > 0 {
                                            Text(L10n.string("settle.changeGivenBackLabel", language: language).replacingOccurrences(of: "%@", with: formatMoney(change, settlementCurrency)))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        if let treated = p.amountTreatedByMe, treated > 0 {
                                            Text(L10n.string("settle.treatedByYouLabel", language: language).replacingOccurrences(of: "%@", with: formatMoney(treated, settlementCurrency)))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        if let ids = p.paymentForExpenseIds {
                                            if ids.isEmpty {
                                                Text(L10n.string("settle.forAllExpenses", language: language))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            } else {
                                                let names = ids.compactMap { id in expenseBreakdown.first(where: { $0.expense.id == id }).map { $0.expense.description.isEmpty ? $0.expense.category.rawValue : $0.expense.description } }
                                                if !names.isEmpty {
                                                    Text("\(L10n.string("settle.paymentFor", language: language)) \(names.joined(separator: ", "))")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        if let note = p.note, !note.isEmpty {
                                            Text(note)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color.appTertiary)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appCard)
                    .cornerRadius(12)
                    
                    // Mark as fully paid — they've paid you back (uses checkboxes above)
                    if isMarkedSettled {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(L10n.string("settle.fullyPaid", language: language))
                                .font(.subheadline.bold())
                                .foregroundColor(.green)
                            Spacer()
                            Button(L10n.string("settle.unmarkPaid", language: language)) {
                                dataStore.toggleSettled(memberId: debtorId)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 4)
                    } else {
                        Button {
                            dataStore.markFullyPaid(debtorId: debtorId, creditorId: creditorId)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .font(.body.bold())
                                Text(stillOwed > 0.001
                                     ? L10n.string("settle.markFullyPaidAnyway", language: language)
                                     : L10n.string("settle.markFullyPaid", language: language))
                                    .font(.subheadline.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(.white)
                            .background(Color(red: 10/255, green: 132/255, blue: 1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle(L10n.string("settle.paymentTitle", language: language).replacingOccurrences(of: "%@", with: memberName(debtorId)))
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("common.done", language: language)) {
                        onDismiss()
                    }
                    .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
                }
            }
        }
    }
}

#Preview {
    SettleUpView()
        .environmentObject(BudgetDataStore())
}
