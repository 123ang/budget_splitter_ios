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
    @State private var selectedMemberId: String = ""
    @State private var settlementCurrency: Currency = CurrencyStore.shared.preferredCurrency
    @State private var selectedDebtorForDetail: String? = nil
    @State private var showTreatedListSheet = false
    @State private var showChangeListSheet = false

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
    
    /// Currencies allowed for the current trip; when nil, all. Used for "Settle in" picker.
    private var allowedCurrenciesForSettle: [Currency] {
        guard let event = dataStore.selectedEvent,
              let allowed = event.allowedCurrencies,
              !allowed.isEmpty else { return Currency.allCases }
        return allowed.sorted(by: { $0.rawValue < $1.rawValue })
    }
    
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

    /// Payments to show for a pair (after last "Mark as fully paid"), so treated/change match the detail sheet.
    private func displayedPaymentsForPair(debtorId: String, creditorId: String) -> [SettlementPayment] {
        let all = dataStore.paymentsFromTo(debtorId: debtorId, creditorId: creditorId)
        guard let after = dataStore.lastSettledAt(debtorId: debtorId, creditorId: creditorId) else { return all }
        return all.filter { $0.date >= after }
    }

    /// Amount you treated (waived) for this debtor–creditor pair (from displayed payments).
    private func treatedForPair(debtorId: String, creditorId: String) -> Double {
        displayedPaymentsForPair(debtorId: debtorId, creditorId: creditorId).reduce(0) { $0 + ($1.amountTreatedByMe ?? 0) }
    }

    /// Change you gave back for this debtor–creditor pair (from displayed payments).
    private func changeForPair(debtorId: String, creditorId: String) -> Double {
        displayedPaymentsForPair(debtorId: debtorId, creditorId: creditorId).reduce(0) { $0 + ($1.changeGivenBack ?? 0) }
    }

    /// Total you've treated (as creditor) across everyone who owes/owed you. Shown in "Your record".
    private var totalTreatedAsCreditor: Double {
        transfersInSettlement
            .filter { $0.to == selectedMemberId }
            .reduce(0) { $0 + treatedForPair(debtorId: $1.from, creditorId: selectedMemberId) }
    }

    /// Total change you've given back (as creditor) across everyone who owes/owed you. Shown in "Your record".
    private var totalChangeAsCreditor: Double {
        transfersInSettlement
            .filter { $0.to == selectedMemberId }
            .reduce(0) { $0 + changeForPair(debtorId: $1.from, creditorId: selectedMemberId) }
    }

    /// All-time treated total (all payments, not filtered by lastSettledAt). Kept in "Your record" after fully paid.
    private var totalTreatedAsCreditorAllTime: Double {
        dataStore.settlementPayments
            .filter { $0.creditorId == selectedMemberId }
            .reduce(0) { $0 + ($1.amountTreatedByMe ?? 0) }
    }

    /// All-time change total (all payments). Kept in "Your record" after fully paid.
    private var totalChangeAsCreditorAllTime: Double {
        dataStore.settlementPayments
            .filter { $0.creditorId == selectedMemberId }
            .reduce(0) { $0 + ($1.changeGivenBack ?? 0) }
    }

    /// Per-member list of treated amounts (who you treated, how much). All-time, for popup.
    private var treatedByMemberList: [(memberId: String, amount: Double)] {
        let paymentsToMe = dataStore.settlementPayments.filter { $0.creditorId == selectedMemberId }
        var sumByDebtor: [String: Double] = [:]
        for p in paymentsToMe {
            let amt = p.amountTreatedByMe ?? 0
            if amt > 0.001 {
                sumByDebtor[p.debtorId, default: 0] += amt
            }
        }
        return sumByDebtor.map { (memberId: $0.key, amount: $0.value) }
            .sorted { memberName(id: $0.memberId).localizedCaseInsensitiveCompare(memberName(id: $1.memberId)) == .orderedAscending }
    }

    /// Per-member list of change given back (who, how much). All-time, for popup.
    private var changeByMemberList: [(memberId: String, amount: Double)] {
        let paymentsToMe = dataStore.settlementPayments.filter { $0.creditorId == selectedMemberId }
        var sumByDebtor: [String: Double] = [:]
        for p in paymentsToMe {
            let amt = p.changeGivenBack ?? 0
            if amt > 0.001 {
                sumByDebtor[p.debtorId, default: 0] += amt
            }
        }
        return sumByDebtor.map { (memberId: $0.key, amount: $0.value) }
            .sorted { memberName(id: $0.memberId).localizedCaseInsensitiveCompare(memberName(id: $1.memberId)) == .orderedAscending }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
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
    }

    private var topControlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title3)
                    .foregroundColor(.appAccent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("settle.viewAs", language: languageStore.language))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Menu {
                        ForEach(settleMembers) { member in
                            Button(member.name) { selectedMemberId = member.id }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(memberName(id: selectedMemberId))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.appPrimary)
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                    .frame(height: 28)
                Image(systemName: "banknote.fill")
                    .font(.title3)
                    .foregroundColor(.appAccent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("settle.settleIn", language: languageStore.language))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Menu {
                        ForEach(allowedCurrenciesForSettle, id: \.self) { c in
                            Button("\(c.symbol) \(c.rawValue)") { settlementCurrency = c }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("\(settlementCurrency.symbol) \(settlementCurrency.rawValue)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.appPrimary)
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .cornerRadius(14)
        .onAppear {
            if selectedMemberId.isEmpty, let first = settleMembers.first { selectedMemberId = first.id }
            var preferred = currencyStore.preferredCurrency
            if !allowedCurrenciesForSettle.contains(preferred) { preferred = allowedCurrenciesForSettle.first ?? preferred }
            settlementCurrency = preferred
        }
        .onChange(of: dataStore.selectedEvent?.id) { _, _ in
            let members = settleMembers
            if selectedMemberId.isEmpty, let first = members.first { selectedMemberId = first.id }
            else if !members.contains(where: { $0.id == selectedMemberId }), let first = members.first { selectedMemberId = first.id }
        }
        .onChange(of: settleMembers.count) { _, _ in
            let members = settleMembers
            if selectedMemberId.isEmpty, let first = members.first { selectedMemberId = first.id }
            else if !members.contains(where: { $0.id == selectedMemberId }), let first = members.first { selectedMemberId = first.id }
        }
    }

    private var iNeedToPayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundColor(.appAccent)
                Text(L10n.string("settle.iNeedToPay", language: languageStore.language))
                    .font(.headline.bold())
                    .foregroundColor(.appPrimary)
            }
            Text(L10n.string("settle.youOweThese", language: languageStore.language).replacingOccurrences(of: "%@", with: settlementCurrency.rawValue))
                .font(.caption)
                .foregroundColor(.secondary)
            if iNeedToPay.isEmpty {
                Text(L10n.string("settle.nothingToPay", language: languageStore.language))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 8) {
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
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Color.appTertiary)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .cornerRadius(14)
    }

    private var whoOweMeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundColor(.appAccent)
                Text(L10n.string("settle.whoOweMe", language: languageStore.language))
                    .font(.headline.bold())
                    .foregroundColor(.appPrimary)
            }
            Text(L10n.string("settle.thesePeopleOweYou", language: languageStore.language).replacingOccurrences(of: "%@", with: settlementCurrency.rawValue))
                .font(.caption)
                .foregroundColor(.secondary)
            if whoOweMe.isEmpty {
                Text(L10n.string("settle.noOneOwesYou", language: languageStore.language))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    ForEach(whoOweMe, id: \.from) { t in
                        whoOweMeRow(t: t)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .cornerRadius(14)
    }

    private func whoOweMeRow(t: (from: String, amount: Double)) -> some View {
        let paid = totalPaidInSettlement(from: t.from, to: selectedMemberId)
        let still = max(0, t.amount - paid)
        let treated = treatedForPair(debtorId: t.from, creditorId: selectedMemberId)
        let change = changeForPair(debtorId: t.from, creditorId: selectedMemberId)
        return Button {
            selectedDebtorForDetail = t.from
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L10n.string("settle.owesYou", language: languageStore.language).replacingOccurrences(of: "%@", with: memberName(id: t.from)))
                        .font(.subheadline)
                        .foregroundColor(.appPrimary)
                    Spacer()
                    Text(still > 0 ? "\(L10n.string("settle.stillOwes", language: languageStore.language)) \(formatMoney(still, settlementCurrency))" : formatMoney(t.amount, settlementCurrency))
                        .font(.subheadline.bold())
                        .foregroundColor(still > 0 ? .orange : .green)
                        .monospacedDigit()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                if treated > 0.001 || change > 0.001 {
                    HStack(spacing: 12) {
                        if treated > 0.001 {
                            Text(L10n.string("settle.recordTreated", language: languageStore.language).replacingOccurrences(of: "%@", with: formatMoney(treated, settlementCurrency)))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if change > 0.001 {
                            Text(L10n.string("settle.recordChange", language: languageStore.language).replacingOccurrences(of: "%@", with: formatMoney(change, settlementCurrency)))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appTertiary)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private var yourRecordCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.title3)
                    .foregroundColor(.appAccent)
                Text(L10n.string("settle.yourRecord", language: languageStore.language))
                    .font(.headline.bold())
                    .foregroundColor(.appPrimary)
            }
            Text(L10n.string("settle.viewAsRecord", language: languageStore.language).replacingOccurrences(of: "%@", with: memberName(id: selectedMemberId)))
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                Button {
                    if totalTreatedAsCreditorAllTime > 0.001 { showTreatedListSheet = true }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(L10n.string("settle.treatedLabelShort", language: languageStore.language))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(formatMoney(totalTreatedAsCreditorAllTime, settlementCurrency))
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.appPrimary)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.appTertiary)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(totalTreatedAsCreditorAllTime <= 0.001)
                Button {
                    if totalChangeAsCreditorAllTime > 0.001 { showChangeListSheet = true }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "banknote.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(L10n.string("settle.changeLabelShort", language: languageStore.language))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(formatMoney(totalChangeAsCreditorAllTime, settlementCurrency))
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.appPrimary)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.appTertiary)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(totalChangeAsCreditorAllTime <= 0.001)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .cornerRadius(14)
        .sheet(isPresented: $showTreatedListSheet) {
            treatedListSheet
        }
        .sheet(isPresented: $showChangeListSheet) {
            changeListSheet
        }
    }

    private var treatedListSheet: some View {
        NavigationStack {
            List {
                ForEach(treatedByMemberList, id: \.memberId) { item in
                    HStack {
                        Text(memberName(id: item.memberId))
                            .font(.subheadline)
                            .foregroundColor(.appPrimary)
                        Spacer()
                        Text(formatMoney(item.amount, settlementCurrency))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.appPrimary)
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle(L10n.string("settle.treatedLabelShort", language: languageStore.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.done", language: languageStore.language)) { showTreatedListSheet = false }
                        .foregroundColor(Color.appAccent)
                }
            }
        }
    }

    private var changeListSheet: some View {
        NavigationStack {
            List {
                ForEach(changeByMemberList, id: \.memberId) { item in
                    HStack {
                        Text(memberName(id: item.memberId))
                            .font(.subheadline)
                            .foregroundColor(.appPrimary)
                        Spacer()
                        Text(formatMoney(item.amount, settlementCurrency))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.appPrimary)
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle(L10n.string("settle.changeLabelShort", language: languageStore.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.done", language: languageStore.language)) { showChangeListSheet = false }
                        .foregroundColor(Color.appAccent)
                }
            }
        }
    }

    @ViewBuilder
    private var whoPaidMeCard: some View {
        if !whoPaidMe.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                    Text(L10n.string("settle.whosPaid", language: languageStore.language))
                        .font(.headline.bold())
                        .foregroundColor(.appPrimary)
                }
                VStack(spacing: 8) {
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
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(Color.appTertiary)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appCard)
            .cornerRadius(14)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if dataStore.expenses.isEmpty {
                    emptyStateView
                } else {
                    topControlsCard
                    iNeedToPayCard
                    whoOweMeCard
                    yourRecordCard
                    whoPaidMeCard
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .id(dataStore.expenses.count)
            .background(Color.appBackground)
            .navigationTitle(dataStore.selectedEvent?.name ?? L10n.string("settle.title", language: languageStore.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BackToTripsButton()
                        .environmentObject(dataStore)
                }
                ToolbarItem(placement: .principal) {
                    Text(dataStore.selectedEvent?.name ?? L10n.string("settle.title", language: languageStore.language))
                        .font(AppFonts.tripTitle)
                        .foregroundColor(.primary)
                }
            }
            .onChange(of: dataStore.selectedEvent?.id) { _, _ in
                if !allowedCurrenciesForSettle.contains(settlementCurrency) {
                    settlementCurrency = allowedCurrenciesForSettle.first ?? settlementCurrency
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
    @State private var showFullyPaidConfirm = false
    @State private var customPaymentAmountText = ""
    @State private var customPaymentNote = ""
    /// When custom payment is used, "From these expenses" is collapsed by default; tap to expand.
    @State private var expandFromTheseExpenses = false

    private var eventId: String? { dataStore.selectedEvent?.id }

    /// For display: when you're treating the shortfall, show 0 so "Mark as fully paid" appears and summary shows treated amount.
    private var displayedStillOwed: Double {
        max(0, stillOwed - totalAmountTreatedByMe)
    }
    
    /// Payments to show: only those on or after last "Mark as fully paid", so old payments are hidden.
    private var displayedPayments: [SettlementPayment] {
        let all = dataStore.paymentsFromTo(debtorId: debtorId, creditorId: creditorId)
        guard let after = dataStore.lastSettledAt(debtorId: debtorId, creditorId: creditorId) else { return all }
        return all.filter { $0.date >= after }
    }

    /// Unallocated (custom) from displayed payments only.
    private var displayedUnallocatedTotal: Double {
        displayedPayments
            .filter { ($0.paymentForExpenseIds ?? []).isEmpty }
            .reduce(0) { $0 + $1.amount }
    }

    /// Unallocated (custom) payments reduce "still owes" without ticking specific expenses. Uses displayed (post–fully paid) only.
    private var customPaymentTotal: Double { displayedUnallocatedTotal }
    private var hasCustomPayment: Bool { customPaymentTotal > 0.001 }

    /// Amount from a list of payments that applies to one expense (for displayed totals).
    private func amountFrom(payments list: [SettlementPayment], toward expenseId: String) -> Double {
        list.reduce(0) { sum, p in
            guard let ids = p.paymentForExpenseIds, !ids.isEmpty, ids.contains(expenseId) else { return sum }
            return sum + (ids.count == 1 ? p.amount : p.amount / Double(ids.count))
        }
    }

    /// Total owed in settlement currency (active/non-settled expenses only).
    private var totalOwed: Double {
        Currency.allCases.reduce(0) { sum, c in
            sum + dataStore.amountOwedActiveOnly(from: debtorId, to: creditorId, currency: c, eventId: eventId) * currencyStore.rate(from: c, to: settlementCurrency)
        }
    }

    /// Total paid: only displayed payments (after last "fully paid") + active expenses (ticked ? share : amount from displayed). Matches "Payments received" list.
    private var totalPaid: Double {
        let unallocated = displayedUnallocatedTotal
        let perExpenseTotal = expenseBreakdown.reduce(0.0) { sum, item in
            let paidToward = amountFrom(payments: displayedPayments, toward: item.expense.id)
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
    
    /// All expenses contributing to debt (including settled), with share in settlement currency.
    private var allExpensesContributingToDebt: [(expense: Expense, share: Double)] {
        Currency.allCases.flatMap { c in
            dataStore.expensesContributingToDebt(creditorId: creditorId, debtorId: debtorId, currency: c, eventId: eventId)
                .map { (expense: $0.expense, share: $0.share * currencyStore.rate(from: c, to: settlementCurrency)) }
        }
    }

    /// Payments to show in "Payments received" (same as displayedPayments).
    private var payments: [SettlementPayment] { displayedPayments }

    /// Expenses marked as paid (for "Payments received"). Only active (non-settled) expenses so old paid items hide after "Mark as fully paid".
    private var paidExpensesFromCheckboxes: [(expense: Expense, share: Double)] {
        expenseBreakdown.filter { dataStore.isExpensePaid(debtorId: debtorId, creditorId: creditorId, expenseId: $0.expense.id) }
    }

    /// Total change given back across displayed payments (when they paid more than owed).
    private var totalChangeGivenBack: Double {
        displayedPayments.reduce(0) { $0 + ($1.changeGivenBack ?? 0) }
    }

    /// Total amount treated by you across displayed payments (when they paid less and you marked/considered paid).
    private var totalAmountTreatedByMe: Double {
        displayedPayments.reduce(0) { $0 + ($1.amountTreatedByMe ?? 0) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Summary: what they owe, what's paid, still owes or fully returned; treated amount at top when you waive shortfall
                    VStack(alignment: .leading, spacing: 10) {
                        if displayedStillOwed > 0.001 && !isMarkedSettled {
                            Text(L10n.string("settle.stillOwes", language: language))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatMoney(displayedStillOwed, settlementCurrency))
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
                        if totalChangeGivenBack > 0.001 {
                            HStack {
                                Text(L10n.string("settle.changeGivenBackLabel", language: language).replacingOccurrences(of: "%@", with: formatMoney(totalChangeGivenBack, settlementCurrency)))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        if totalAmountTreatedByMe > 0.001 {
                            HStack {
                                Text(L10n.string("settle.treatedByYouLabel", language: language).replacingOccurrences(of: "%@", with: formatMoney(totalAmountTreatedByMe, settlementCurrency)))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        if displayedStillOwed <= 0.001 || isMarkedSettled {
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
                    
                    // What they owe for — when custom payment is used, collapse by default (tap to expand); else show checkboxes
                    if !expenseBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            if hasCustomPayment {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { expandFromTheseExpenses.toggle() }
                                } label: {
                                    HStack {
                                        Text(L10n.string("settle.fromTheseExpenses", language: language))
                                            .font(.headline.bold())
                                            .foregroundColor(.appPrimary)
                                        Spacer()
                                        Image(systemName: expandFromTheseExpenses ? "chevron.up" : "chevron.down")
                                            .font(.caption.bold())
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                                if expandFromTheseExpenses {
                                    ForEach(expenseBreakdown, id: \.expense.id) { item in
                                        HStack {
                                            Text(item.expense.description.isEmpty ? item.expense.category.rawValue : item.expense.description)
                                                .font(.subheadline)
                                                .foregroundColor(.appPrimary)
                                                .lineLimit(1)
                                            Spacer()
                                            Text(formatMoney(item.share, settlementCurrency))
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .monospacedDigit()
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(Color.appTertiary)
                                        .cornerRadius(8)
                                    }
                                }
                            } else {
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
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appCard)
                        .cornerRadius(12)
                    }
                    
                    // Record custom payment — amount deducts from "still owes"
                    if !isMarkedSettled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("settle.recordCustomPayment", language: language))
                                .font(.headline.bold())
                                .foregroundColor(.appPrimary)
                            HStack(spacing: 8) {
                                TextField(L10n.string("settle.customPaymentAmount", language: language), text: $customPaymentAmountText)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                Text(settlementCurrency.symbol)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            TextField(L10n.string("settle.customPaymentNote", language: language), text: $customPaymentNote)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                let raw = customPaymentAmountText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                                guard let amountReceived = Double(raw), amountReceived > 0 else { return }
                                let stillOwedNow = stillOwed
                                let amountApplied: Double
                                let changeGivenBack: Double?
                                let amountTreatedByMe: Double?
                                if amountReceived >= stillOwedNow {
                                    amountApplied = stillOwedNow
                                    changeGivenBack = amountReceived - stillOwedNow > 0.001 ? amountReceived - stillOwedNow : nil
                                    amountTreatedByMe = nil
                                } else {
                                    amountApplied = amountReceived
                                    changeGivenBack = nil
                                    amountTreatedByMe = stillOwedNow - amountReceived
                                }
                                dataStore.addSettlementPayment(
                                    debtorId: debtorId,
                                    creditorId: creditorId,
                                    amount: amountApplied,
                                    note: customPaymentNote.isEmpty ? nil : customPaymentNote,
                                    amountReceived: amountReceived,
                                    changeGivenBack: changeGivenBack,
                                    amountTreatedByMe: amountTreatedByMe,
                                    paymentForExpenseIds: nil
                                )
                                customPaymentAmountText = ""
                                customPaymentNote = ""
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text(L10n.string("settle.addPayment", language: language))
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.appAccent)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(customPaymentAmountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                                    let paidToward = amountFrom(payments: displayedPayments, toward: item.expense.id)
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
                                        Text(formatMoney(p.amount, settlementCurrency))
                                            .font(.subheadline.bold())
                                            .foregroundColor(.green)
                                            .monospacedDigit()
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
                                        } else {
                                            Text(L10n.string("settle.customPaymentLabel", language: language))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
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
                    
                    // Mark as fully paid — only when they've paid in full (stillOwed <= 0); no "mark as fully paid anyway"
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
                    } else if displayedStillOwed <= 0.001 {
                        Button {
                            showFullyPaidConfirm = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .font(.body.bold())
                                Text(L10n.string("settle.markFullyPaid", language: language))
                                    .font(.subheadline.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(.white)
                            .background(Color.appAccent)
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
                    .foregroundColor(Color.appAccent)
                }
            }
            .confirmationDialog(L10n.string("settle.paymentFullySettledTitle", language: language), isPresented: $showFullyPaidConfirm, titleVisibility: .visible) {
                Button(L10n.string("common.confirm", language: language)) {
                    dataStore.markFullyPaid(debtorId: debtorId, creditorId: creditorId)
                    onDismiss()
                }
                Button(L10n.string("common.cancel", language: language), role: .cancel) {}
            } message: {
                Text(L10n.string("settle.paymentFullySettledMessage", language: language))
            }
        }
    }
}

#Preview {
    SettleUpView()
        .environmentObject(BudgetDataStore())
}
