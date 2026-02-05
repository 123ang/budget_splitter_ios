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
    
    private func memberName(id: String) -> String {
        dataStore.members.first(where: { $0.id == id })?.name ?? "—"
    }
    
    /// All (from, to) pairs that appear in any currency's settlement.
    private var allTransferPairs: [(from: String, to: String)] {
        var pairs: [(from: String, to: String)] = []
        var seen = Set<String>()
        for c in Currency.allCases {
            for t in dataStore.settlementTransfers(currency: c) {
                let key = "\(t.from)|\(t.to)"
                if !seen.contains(key) {
                    seen.insert(key)
                    pairs.append((t.from, t.to))
                }
            }
        }
        return pairs
    }
    
    /// Amount owed from debtor to creditor in settlement currency (all expense currencies converted).
    private func amountOwedInCurrency(from: String, to: String, in target: Currency) -> Double {
        Currency.allCases.reduce(0) { sum, c in
            sum + dataStore.amountOwed(from: from, to: to, currency: c) * currencyStore.rate(from: c, to: target)
        }
    }
    
    /// Total paid from debtor to creditor in settlement terms (recorded payments + checkbox-paid converted).
    private func totalPaidInSettlement(from debtorId: String, to creditorId: String) -> Double {
        let recorded = dataStore.totalPaidFromTo(debtorId: debtorId, creditorId: creditorId)
        let fromCheckboxes = Currency.allCases.reduce(0) { sum, c in
            sum + dataStore.totalPaidViaExpenseCheckboxes(debtorId: debtorId, creditorId: creditorId, currency: c) * currencyStore.rate(from: c, to: settlementCurrency)
        }
        return recorded + fromCheckboxes
    }
    
    /// Transfers in settlement currency (who owes whom, converted so creditor can choose MYR or Yen etc).
    private var transfersInSettlement: [(from: String, to: String, amount: Double)] {
        allTransferPairs
            .map { (from: $0.from, to: $0.to, amount: amountOwedInCurrency(from: $0.from, to: $0.to, in: settlementCurrency)) }
            .filter { $0.amount > 0.001 }
    }
    
    /// Transfers where the selected member owes (I need to pay).
    private var iNeedToPay: [(to: String, amount: Double)] {
        transfersInSettlement.filter { $0.from == selectedMemberId }.map { (to: $0.to, amount: $0.amount) }
    }
    
    /// Transfers where others owe the selected member (Who owe me). Excludes people already marked paid.
    private var whoOweMe: [(from: String, amount: Double)] {
        transfersInSettlement
            .filter { $0.to == selectedMemberId && !dataStore.settledMemberIds.contains($0.from) }
            .map { (from: $0.from, amount: $0.amount) }
    }
    
    /// People who owe me and are marked as paid (for "Who's paid?" section).
    private var whoPaidMe: [(from: String, amount: Double)] {
        transfersInSettlement
            .filter { $0.to == selectedMemberId && dataStore.settledMemberIds.contains($0.from) }
            .map { (from: $0.from, amount: $0.amount) }
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
                            Text("No expenses yet")
                                .font(.headline)
                                .foregroundColor(.appPrimary)
                            Text("Add expenses first, then come here to see who owes whom.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                    } else {
                        // Member picker — view as (tappable menu)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("View as")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Menu {
                                ForEach(dataStore.members) { member in
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
                                if selectedMemberId.isEmpty, let first = dataStore.members.first {
                                    selectedMemberId = first.id
                                }
                            }
                            .onChange(of: dataStore.members.count) { _, _ in
                                if selectedMemberId.isEmpty, let first = dataStore.members.first {
                                    selectedMemberId = first.id
                                } else if !dataStore.members.contains(where: { $0.id == selectedMemberId }),
                                          let first = dataStore.members.first {
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
                            Text("Settle in")
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
                            Text("I need to pay")
                                .font(.headline.bold())
                                .foregroundColor(.appPrimary)
                            Text("You owe these people (\(settlementCurrency.rawValue))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if iNeedToPay.isEmpty {
                                Text("Nothing to pay.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(Array(iNeedToPay.enumerated()), id: \.offset) { _, t in
                                    HStack {
                                        Text("You owe \(memberName(id: t.to))")
                                            .font(.subheadline)
                                            .foregroundColor(.appPrimary)
                                        Spacer()
                                        Text(formatMoney(t.amount, settlementCurrency))
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
                            Text("Who owe me")
                                .font(.headline.bold())
                                .foregroundColor(.appPrimary)
                            Text("These people owe you (\(settlementCurrency.rawValue)). Tap to add payments or mark paid.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if whoOweMe.isEmpty {
                                Text("No one owes you.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(Array(whoOweMe.enumerated()), id: \.offset) { _, t in
                                    Button {
                                        selectedDebtorForDetail = t.from
                                    } label: {
                                        HStack {
                                            Text("\(memberName(id: t.from)) owes you")
                                                .font(.subheadline)
                                                .foregroundColor(.appPrimary)
                                            Spacer()
                                            let paid = totalPaidInSettlement(from: t.from, to: selectedMemberId)
                                            let still = max(0, t.amount - paid)
                                            Text(still > 0 ? "Still owes \(formatMoney(still, settlementCurrency))" : formatMoney(t.amount, settlementCurrency))
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
                        
                        // Who's paid? — people who owed me and are marked paid; tap for payment details
                        if !whoPaidMe.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Who's paid?")
                                    .font(.headline.bold())
                                    .foregroundColor(.appPrimary)
                                Text("Tap for payment details.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(Array(whoPaidMe.enumerated()), id: \.offset) { _, t in
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
            .background(Color.appBackground)
            .navigationTitle("Settle up")
            .navigationBarTitleDisplayMode(.inline)
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
    let onDismiss: () -> Void
    
    @State private var addAmountText: String = ""
    @State private var addNoteText: String = ""
    @FocusState private var amountFocused: Bool
    
    /// Total owed in settlement currency (all expense currencies converted).
    private var totalOwed: Double {
        Currency.allCases.reduce(0) { sum, c in
            sum + dataStore.amountOwed(from: debtorId, to: creditorId, currency: c) * currencyStore.rate(from: c, to: settlementCurrency)
        }
    }
    
    /// Total paid: recorded payments (treated as settlement currency) + checkbox-paid shares converted to settlement.
    private var totalPaid: Double {
        let recorded = dataStore.totalPaidFromTo(debtorId: debtorId, creditorId: creditorId)
        let fromCheckboxes = Currency.allCases.reduce(0) { sum, c in
            sum + dataStore.totalPaidViaExpenseCheckboxes(debtorId: debtorId, creditorId: creditorId, currency: c) * currencyStore.rate(from: c, to: settlementCurrency)
        }
        return recorded + fromCheckboxes
    }
    
    private var stillOwed: Double {
        max(0, totalOwed - totalPaid)
    }
    
    private var isMarkedSettled: Bool {
        dataStore.settledMemberIds.contains(debtorId)
    }
    
    /// All expenses contributing to debt with share in settlement currency.
    private var expenseBreakdown: [(expense: Expense, share: Double)] {
        Currency.allCases.flatMap { c in
            dataStore.expensesContributingToDebt(creditorId: creditorId, debtorId: debtorId, currency: c)
                .map { (expense: $0.expense, share: $0.share * currencyStore.rate(from: c, to: settlementCurrency)) }
        }
    }
    
    private var payments: [SettlementPayment] {
        dataStore.paymentsFromTo(debtorId: debtorId, creditorId: creditorId)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Total owed & still owes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Total owed to you")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatMoney(totalOwed, settlementCurrency))
                            .font(.title2.bold())
                            .foregroundColor(.appPrimary)
                            .monospacedDigit()
                        HStack {
                            Text("Paid so far:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(formatMoney(totalPaid, settlementCurrency))
                                .font(.subheadline.bold())
                                .foregroundColor(.green)
                                .monospacedDigit()
                        }
                        if stillOwed <= 0 || isMarkedSettled {
                            Text("Fully returned. Nothing to owe.")
                                .font(.subheadline.bold())
                                .foregroundColor(.green)
                            HStack {
                                Text("Still owes:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formatMoney(0, settlementCurrency))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.green)
                                    .monospacedDigit()
                            }
                        } else {
                            HStack {
                                Text("Still owes:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formatMoney(stillOwed, settlementCurrency))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.orange)
                                    .monospacedDigit()
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appCard)
                    .cornerRadius(12)
                    
                    // What they owe for (expense breakdown) — checkbox per expense; when checked, amount deducts from total owe
                    if !expenseBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("From these expenses")
                                .font(.headline.bold())
                                .foregroundColor(.appPrimary)
                            Text("Tick when they’ve paid that expense.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(expenseBreakdown, id: \.expense.id) { item in
                                HStack {
                                    Text(item.expense.description.isEmpty ? "Expense" : item.expense.description)
                                        .font(.subheadline)
                                        .foregroundColor(.appPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(formatMoney(item.share, settlementCurrency))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
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
                    
                    // Recorded payments (what they paid)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Payments received")
                            .font(.headline.bold())
                            .foregroundColor(.appPrimary)
                        if payments.isEmpty {
                            Text("No payments recorded yet.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(payments) { p in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(formatMoney(p.amount, settlementCurrency))
                                            .font(.subheadline.bold())
                                            .foregroundColor(.green)
                                            .monospacedDigit()
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
                    
                    // Add payment (only if still owes)
                    if stillOwed > 0 {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Add payment")
                                .font(.headline.bold())
                                .foregroundColor(.appPrimary)
                            HStack(spacing: 8) {
                                TextField("Amount (\(settlementCurrency.rawValue))", text: $addAmountText)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($amountFocused)
                                TextField("Note (e.g. ramen)", text: $addNoteText)
                                    .textFieldStyle(.roundedBorder)
                            }
                            Button("Record payment") {
                                guard let amount = Double(addAmountText.replacingOccurrences(of: ",", with: "")), amount > 0 else { return }
                                dataStore.addSettlementPayment(debtorId: debtorId, creditorId: creditorId, amount: amount, note: addNoteText.isEmpty ? nil : addNoteText)
                                addAmountText = ""
                                addNoteText = ""
                                amountFocused = false
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 10/255, green: 132/255, blue: 1))
                            .disabled(addAmountText.isEmpty)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appCard)
                        .cornerRadius(12)
                    }
                    
                    // Mark as fully paid / Unmark
                    if stillOwed <= 0 && !isMarkedSettled {
                        Button("Mark as fully paid") {
                            dataStore.toggleSettled(memberId: debtorId)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .frame(maxWidth: .infinity)
                    } else if stillOwed > 0 {
                        if isMarkedSettled {
                            Button("Unmark as paid") {
                                dataStore.toggleSettled(memberId: debtorId)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        } else {
                            Button("Mark as fully paid anyway") {
                                dataStore.toggleSettled(memberId: debtorId)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("\(memberName(debtorId))'s payment")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
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
