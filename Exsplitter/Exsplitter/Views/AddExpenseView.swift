//
//  AddExpenseView.swift
//  BudgetSplitter
//

import SwiftUI
import UIKit

/// Who pays for this expense: payer treats everyone (full amount on payer) or split with others.
enum ExpenseSplitMode: String, CaseIterable {
    case treatEveryone = "I'm treating"
    case splitWithOthers = "Split with others"
}

enum SplitType: String, CaseIterable {
    case equal = "Equal"
    case custom = "Custom"
}

/// When payer is not in the split: how to handle rounding extra.
enum PayerNotInSplitOption: String, CaseIterable {
    case randomExtra = "Random split extra"
    case payerEarns = "Everyone pays a bit more (payer earns)"
}

struct AddExpenseView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @ObservedObject private var languageStore = LanguageStore.shared
    @State private var description = ""
    @State private var amountText = ""
    @State private var category: ExpenseCategory = .meal
    @State private var currency: Currency = CurrencyStore.shared.preferredCurrency
    @State private var paidByMemberId: String = ""
    @State private var date = Date()
    @State private var splitType: SplitType = .equal
    @State private var customAmounts: [String: String] = [:] // memberId -> amount text
    @State private var payerNotInSplitOption: PayerNotInSplitOption = .randomExtra
    @State private var showSuccessToast = false
    @State private var addErrorMessage: String?
    @State private var isAddingExpense = false
    @State private var customSplitError: String?
    /// Who is included in this expense's split (checkboxes). Independent from global "selected" members.
    @State private var splitMemberIdsForThisExpense: Set<String> = []
    /// nil = must choose; .treatEveryone = full expense on payer; .splitWithOthers = show Equal/Custom.
    @State private var expenseSplitMode: ExpenseSplitMode? = nil
    private let iosBlue = Color(red: 10/255, green: 132/255, blue: 1)
    
    private var canAddExpense: Bool {
        guard let mode = expenseSplitMode else { return false }
        if mode == .treatEveryone { return true }
        return !selectedIds.isEmpty
    }
    
    /// Members for the current trip (or global when no trip). Expense payer/split use this list only.
    private var expenseMembers: [Member] {
        dataStore.members(for: dataStore.selectedEvent?.id)
    }
    
    /// Members selected for this expense's split (sorted by member order).
    private var selectedIds: [String] {
        expenseMembers
            .filter { splitMemberIdsForThisExpense.contains($0.id) }
            .map(\.id)
    }
    
    private var payerIsInSplit: Bool {
        selectedIds.contains(paidByMemberId)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Form card
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.string("addExpense.title", language: languageStore.language))
                            .font(.headline.bold())
                            .foregroundColor(.appPrimary)
                        
                        InputField(label: L10n.string("addExpense.description", language: languageStore.language), text: $description, placeholder: L10n.string("addExpense.descriptionPlaceholder", language: languageStore.language))
                        InputField(label: L10n.string("addExpense.amount", language: languageStore.language), text: $amountText, placeholder: L10n.string("addExpense.amountPlaceholder", language: languageStore.language), keyboardType: .decimalPad)
                        
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.string("addExpense.category", language: languageStore.language))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                CategoryPicker(selection: $category)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.string("addExpense.currency", language: languageStore.language))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                CurrencyPicker(selection: $currency)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.string("addExpense.paidBy", language: languageStore.language))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                MemberPicker(dataStore: dataStore, selection: $paidByMemberId)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.string("addExpense.date", language: languageStore.language))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .labelsHidden()
                                    .padding(8)
                                    .background(Color.appTertiary)
                                    .cornerRadius(8)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("addExpense.whoPaysForThis", language: languageStore.language))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Picker(L10n.string("addExpense.whoPaysForThis", language: languageStore.language), selection: $expenseSplitMode) {
                                Text(L10n.string("addExpense.choose", language: languageStore.language)).tag(nil as ExpenseSplitMode?)
                                ForEach(ExpenseSplitMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode as ExpenseSplitMode?)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: expenseSplitMode) { _, _ in
                                customSplitError = nil
                            }
                            
                            if expenseSplitMode == .treatEveryone {
                                Text(L10n.string("addExpense.treatEveryoneDesc", language: languageStore.language))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            if expenseSplitMode == .splitWithOthers {
                                Text(String(format: L10n.string("addExpense.splitWith", language: languageStore.language), selectedIds.count))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(L10n.string("addExpense.selectWhoInSplit", language: languageStore.language))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                VStack(spacing: 6) {
                                    ForEach(expenseMembers) { member in
                                        Toggle(isOn: Binding(
                                            get: { splitMemberIdsForThisExpense.contains(member.id) },
                                            set: { on in
                                                if on {
                                                    splitMemberIdsForThisExpense.insert(member.id)
                                                } else {
                                                    splitMemberIdsForThisExpense.remove(member.id)
                                                }
                                            }
                                        )) {
                                            Text(member.name)
                                                .font(.subheadline)
                                                .foregroundColor(.appPrimary)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(Color.appTertiary)
                                        .cornerRadius(8)
                                    }
                                }
                                Picker("Split", selection: $splitType) {
                                    ForEach(SplitType.allCases, id: \.self) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: splitType) { _, new in
                                    if new == .equal { customSplitError = nil }
                                }
                                if splitType == .custom {
                                    customSplitFields
                                    if let err = customSplitError {
                                        Text(err)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                            .padding(.top, 4)
                                    }
                                } else {
                                    Text(L10n.string("addExpense.equalSplitDesc", language: languageStore.language))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    if !payerIsInSplit {
                                        Text(L10n.string("addExpense.paidByNotInSplit", language: languageStore.language))
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                        Picker("Extra from rounding", selection: $payerNotInSplitOption) {
                                            ForEach(PayerNotInSplitOption.allCases, id: \.self) { opt in
                                                Text(opt.rawValue).tag(opt)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }
                                }
                            }
                        }
                        
                        if expenseSplitMode == nil {
                            Text("Choose \"I'm treating\" or \"Split with others\" above to add an expense.")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        
                        if let err = addErrorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.top, 4)
                        }
                        Button {
                            addExpense()
                        } label: {
                            HStack {
                                if isAddingExpense {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                    Text(L10n.string("addExpense.title", language: languageStore.language))
                                }
                            }
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(iosBlue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!canAddExpense || isAddingExpense)
                        .opacity(canAddExpense && !isAddingExpense ? 1 : 0.6)
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color.appCard)
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle(dataStore.selectedEvent?.name ?? "💰 \(L10n.string("members.navTitle", language: languageStore.language))")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .onAppear {
                currency = CurrencyStore.shared.preferredCurrency
                let members = expenseMembers
                if paidByMemberId.isEmpty, let first = members.first {
                    paidByMemberId = first.id
                }
                if splitMemberIdsForThisExpense.isEmpty {
                    let defaultIds = dataStore.selectedMemberIds.isEmpty
                        ? Set(members.map(\.id))
                        : dataStore.selectedMemberIds
                    splitMemberIdsForThisExpense = defaultIds.filter { members.map(\.id).contains($0) }
                    if splitMemberIdsForThisExpense.isEmpty, !members.isEmpty {
                        splitMemberIdsForThisExpense = Set(members.map(\.id))
                    }
                }
            }
            .onChange(of: dataStore.selectedEvent?.id) { _, new in
                guard let id = new else { return }
                let members = dataStore.members(for: id)
                let memberIds = Set(members.map(\.id))
                splitMemberIdsForThisExpense = splitMemberIdsForThisExpense.filter { memberIds.contains($0) }
                if splitMemberIdsForThisExpense.isEmpty { splitMemberIdsForThisExpense = memberIds }
                if paidByMemberId.isEmpty || !memberIds.contains(paidByMemberId) {
                    paidByMemberId = members.first?.id ?? ""
                }
            }
            .onChange(of: expenseMembers.count) { _, _ in
                let memberIds = Set(expenseMembers.map(\.id))
                splitMemberIdsForThisExpense = splitMemberIdsForThisExpense.filter { memberIds.contains($0) }
                for id in memberIds where !splitMemberIdsForThisExpense.contains(id) {
                    splitMemberIdsForThisExpense.insert(id)
                }
            }
            .overlay(alignment: .top) {
                if showSuccessToast {
                    successToast
                        .padding(.top, 12)
                }
            }
        }
    }
    
    @ViewBuilder
    private var customSplitFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: L10n.string("addExpense.enterEachShare", language: languageStore.language), currency.symbol))
                .font(.caption2)
                .foregroundColor(.secondary)
            ForEach(selectedIds, id: \.self) { memberId in
                let name = expenseMembers.first(where: { $0.id == memberId })?.name ?? "—"
                HStack {
                    Text(name)
                        .font(.subheadline)
                        .foregroundColor(.appPrimary)
                        .lineLimit(1)
                    Spacer()
                    TextField("0", text: Binding(
                        get: { customAmounts[memberId] ?? "" },
                        set: { customAmounts[memberId] = $0; customSplitError = nil }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .padding(8)
                    .background(Color.appTertiary)
                    .cornerRadius(8)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var successToast: some View {
        Text(L10n.string("addExpense.successfullyAdded", language: languageStore.language))
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.green)
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .zIndex(100)
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func addExpense() {
        let cleaned = amountText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        guard let amount = Double(cleaned), amount > 0 else { return }
        guard !paidByMemberId.isEmpty else { return }
        guard canAddExpense else { return }
        
        let ids: [String]
        var splits: [String: Double]
        var payerEarned: Double? = nil
        
        if expenseSplitMode == .treatEveryone {
            // Payer treats: full amount on payer only, no one else owes anything.
            ids = [paidByMemberId]
            splits = [paidByMemberId: amount]
        } else {
            guard !selectedIds.isEmpty else {
                customSplitError = "Select at least one person for the split."
                return
            }
            ids = selectedIds
            
        if splitType == .custom {
            customSplitError = nil
            var sum: Double = 0
            var parsed: [String: Double] = [:]
            for id in ids {
                let t = (customAmounts[id] ?? "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
                let val = Double(t) ?? 0
                parsed[id] = max(0, currency == .JPY ? floor(val) : (val * 100).rounded() / 100)
                sum += parsed[id] ?? 0
            }
            if sum <= 0 {
                customSplitError = "Enter at least one amount."
                return
            }
            let tolerance = currency == .JPY ? 0.5 : 0.005
            if abs(sum - amount) > tolerance {
                let sym = currency.symbol
                let fmt = currency == .JPY ? "%.0f" : "%.2f"
                customSplitError = "Custom split does not tally. Total entered: \(sym)\(String(format: fmt, sum)), expense amount: \(sym)\(String(format: fmt, amount))."
                return
            }
            splits = parsed
        } else {
            // Equal split
            let n = Double(ids.count)
            let perPerson = amount / n
            let payerInSplit = ids.contains(paidByMemberId)
            
            if payerInSplit {
                // Others pay a bit more (ceil), payer pays the rest so payer pays less and "earns" the extra
                let othersShare = currency == .JPY ? ceil(perPerson) : (perPerson * 100).rounded(.up) / 100
                var totalOthers: Double = 0
                splits = [:]
                for id in ids {
                    if id == paidByMemberId {
                        continue
                    }
                    splits[id] = othersShare
                    totalOthers += othersShare
                }
                let payerShare = amount - totalOthers
                splits[paidByMemberId] = max(0, payerShare)
            } else {
                // Payer not in split
                if payerNotInSplitOption == .randomExtra {
                    var remainder = amount
                    splits = [:]
                    let baseShare = currency == .JPY ? floor(perPerson) : (perPerson * 100).rounded() / 100
                    for id in ids {
                        splits[id] = baseShare
                        remainder -= baseShare
                    }
                    if remainder > 0 {
                        let whoGetsExtra = ids.shuffled()
                        var r = remainder
                        for id in whoGetsExtra where r > 0 {
                            let add = currency == .JPY ? 1.0 : 0.01
                            splits[id, default: 0] += min(add, r)
                            r -= add
                        }
                    }
                } else {
                    // Everyone pays a bit more (payer earns)
                    let ceilShare = currency == .JPY ? ceil(perPerson) : (perPerson * 100).rounded(.up) / 100
                    var totalFromMembers: Double = 0
                    splits = [:]
                    for id in ids {
                        splits[id] = ceilShare
                        totalFromMembers += ceilShare
                    }
                    payerEarned = max(0, totalFromMembers - amount)
                }
            }
        }
        } // end else (split with others)
        
        let expense = Expense(
            description: description.trimmingCharacters(in: .whitespaces),
            amount: amount,
            category: category,
            currency: currency,
            paidByMemberId: paidByMemberId,
            date: date,
            splitMemberIds: ids,
            splits: splits,
            payerEarned: payerEarned,
            eventId: dataStore.selectedEvent?.id
        )
        addErrorMessage = nil
        isAddingExpense = true
        dataStore.addExpense(expense)
        dismissKeyboard()
        description = ""
        amountText = ""
        customAmounts = [:]
        withAnimation(.easeInOut(duration: 0.2)) { showSuccessToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.25)) { showSuccessToast = false }
        }
        isAddingExpense = false
    }
}

struct InputField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .padding(10)
                .background(Color.appTertiary)
                .foregroundColor(.appPrimary)
                .cornerRadius(8)
        }
    }
}

struct CategoryPicker: View {
    @Binding var selection: ExpenseCategory
    
    var body: some View {
        Menu {
            ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                Button {
                    selection = cat
                } label: {
                    HStack {
                        Image(systemName: cat.icon)
                        Text(cat.rawValue)
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: selection.icon)
                Text(selection.rawValue)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(10)
            .background(Color.appTertiary)
            .foregroundColor(.appPrimary)
            .cornerRadius(8)
        }
    }
}

struct CurrencyPicker: View {
    @Binding var selection: Currency
    
    var body: some View {
        Menu {
            ForEach(Currency.allCases, id: \.self) { curr in
                Button {
                    selection = curr
                } label: {
                    Text("\(curr.rawValue) (\(curr.symbol))")
                }
            }
        } label: {
            HStack {
                Text("\(selection.rawValue) (\(selection.symbol))")
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(10)
            .background(Color.appTertiary)
            .foregroundColor(.appPrimary)
            .cornerRadius(8)
        }
    }
}

struct MemberPicker: View {
    @ObservedObject var dataStore: BudgetDataStore
    @Binding var selection: String
    
    private var members: [Member] { dataStore.members(for: dataStore.selectedEvent?.id) }
    
    var body: some View {
        Menu {
            ForEach(members) { member in
                Button {
                    selection = member.id
                } label: {
                    Text(member.name)
                }
            }
        } label: {
            HStack {
                Text(members.first(where: { $0.id == selection })?.name ?? "Select")
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(10)
            .background(Color.appTertiary)
            .foregroundColor(.appPrimary)
            .cornerRadius(8)
        }
    }
}

#Preview {
    AddExpenseView()
        .environmentObject(BudgetDataStore())
}
