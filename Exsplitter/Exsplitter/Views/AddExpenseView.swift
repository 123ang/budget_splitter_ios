//
//  AddExpenseView.swift
//  Xsplitter
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
    /// When set, form is in edit mode: pre-fills and calls updateExpense on save.
    var existingExpense: Expense? = nil
    @EnvironmentObject var dataStore: BudgetDataStore
    @ObservedObject private var languageStore = LanguageStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var didPrefillForEdit = false
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
    
    private var canAddExpense: Bool {
        guard let mode = expenseSplitMode else { return false }
        if mode == .treatEveryone { return true }
        return !selectedIds.isEmpty
    }
    
    /// Members for the current trip (or global when no trip). Expense payer/split use this list only.
    private var expenseMembers: [Member] {
        dataStore.members(for: dataStore.selectedEvent?.id)
    }
    
    /// Currencies allowed for the current trip; nil = all. Used for Add expense currency picker.
    private var allowedCurrenciesForExpense: [Currency]? {
        guard let event = dataStore.selectedEvent,
              let allowed = event.allowedCurrencies,
              !allowed.isEmpty else { return nil }
        return allowed.sorted(by: { $0.rawValue < $1.rawValue })
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
                        Text(existingExpense != nil ? L10n.string("addExpense.editTitle", language: languageStore.language) : L10n.string("addExpense.title", language: languageStore.language))
                            .font(.headline.bold())
                            .foregroundColor(.appPrimary)
                        
                        InputField(label: L10n.string("addExpense.description", language: languageStore.language), text: $description, placeholder: L10n.string("addExpense.descriptionPlaceholder", language: languageStore.language))
                        InputField(label: L10n.string("addExpense.amount", language: languageStore.language), text: $amountText, placeholder: L10n.string("addExpense.amountPlaceholder", language: languageStore.language), keyboardType: .decimalPad)
                            .onChange(of: amountText) { _, newValue in
                                let filtered = newValue.filter { $0.isNumber || $0 == "." || $0 == "," }
                                let parts = filtered.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
                                let allowed = parts.count <= 1 ? filtered : String(parts[0]) + "." + parts[1].filter { $0.isNumber }
                                if allowed != newValue { amountText = allowed }
                                addErrorMessage = nil
                            }
                        
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
                                CurrencyPicker(selection: $currency, allowedCurrencies: allowedCurrenciesForExpense)
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
                                Text(L10n.string("addExpense.treatEveryone", language: languageStore.language)).tag(ExpenseSplitMode.treatEveryone as ExpenseSplitMode?)
                                Text(L10n.string("addExpense.splitWithOthers", language: languageStore.language)).tag(ExpenseSplitMode.splitWithOthers as ExpenseSplitMode?)
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: expenseSplitMode) { _, newMode in
                                customSplitError = nil
                                if newMode == .splitWithOthers {
                                    splitMemberIdsForThisExpense = Set(expenseMembers.map(\.id))
                                }
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
                                Picker(L10n.string("addExpense.splitPicker", language: languageStore.language), selection: $splitType) {
                                    Text(L10n.string("addExpense.splitEqual", language: languageStore.language)).tag(SplitType.equal)
                                    Text(L10n.string("addExpense.splitCustom", language: languageStore.language)).tag(SplitType.custom)
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
                                        Picker(L10n.string("addExpense.extraFromRounding", language: languageStore.language), selection: $payerNotInSplitOption) {
                                            Text(L10n.string("addExpense.payerNotInSplitRandom", language: languageStore.language)).tag(PayerNotInSplitOption.randomExtra)
                                            Text(L10n.string("addExpense.payerNotInSplitEarns", language: languageStore.language)).tag(PayerNotInSplitOption.payerEarns)
                                        }
                                        .pickerStyle(.menu)
                                    }
                                }
                            }
                        }
                        
                        if expenseSplitMode == nil {
                            Text(L10n.string("addExpense.chooseTreatOrSplit", language: languageStore.language))
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
                                    Image(systemName: existingExpense != nil ? "pencil.circle.fill" : "plus.circle.fill")
                                    Text(existingExpense != nil ? L10n.string("common.save", language: languageStore.language) : L10n.string("addExpense.title", language: languageStore.language))
                                }
                            }
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.appAccent)
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
            .navigationTitle(existingExpense != nil ? L10n.string("addExpense.editTitle", language: languageStore.language) : (dataStore.selectedEvent?.name ?? "💰 \(L10n.string("members.navTitle", language: languageStore.language))"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(existingExpense != nil ? L10n.string("addExpense.editTitle", language: languageStore.language) : (dataStore.selectedEvent?.name ?? "💰 \(L10n.string("members.navTitle", language: languageStore.language))"))
                        .font(AppFonts.tripTitle)
                        .foregroundColor(.primary)
                }
            }
            .keyboardDoneButton()
            .alert(L10n.string("addExpense.amount", language: languageStore.language), isPresented: Binding(get: { addErrorMessage != nil }, set: { if !$0 { addErrorMessage = nil } })) {
                Button(L10n.string("common.done", language: languageStore.language)) { addErrorMessage = nil }
            } message: {
                Text(addErrorMessage ?? "")
            }
            .onAppear {
                if let e = existingExpense, !didPrefillForEdit {
                    prefillFromExpense(e)
                    didPrefillForEdit = true
                    return
                }
                guard existingExpense == nil else { return }
                var preferred = dataStore.selectedEvent?.mainCurrency ?? CurrencyStore.shared.preferredCurrency
                if let allowed = allowedCurrenciesForExpense, !allowed.isEmpty, !allowed.contains(preferred) {
                    preferred = allowed[0]
                }
                currency = preferred
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
                if let allowed = dataStore.selectedEvent.flatMap({ $0.allowedCurrencies }).map({ Array($0).sorted(by: { $0.rawValue < $1.rawValue }) }), !allowed.isEmpty, !allowed.contains(currency) {
                    currency = allowed[0]
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
        Text(existingExpense != nil ? L10n.string("addExpense.successfullyUpdated", language: languageStore.language) : L10n.string("addExpense.successfullyAdded", language: languageStore.language))
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
    
    private func prefillFromExpense(_ e: Expense) {
        description = e.description
        amountText = e.currency == .JPY ? String(format: "%.0f", e.amount) : String(format: "%.2f", e.amount)
        category = e.category
        currency = e.currency
        paidByMemberId = e.paidByMemberId
        date = e.date
        splitMemberIdsForThisExpense = Set(e.splitMemberIds)
        if e.splitMemberIds.count == 1 && e.splitMemberIds[0] == e.paidByMemberId {
            expenseSplitMode = .treatEveryone
        } else {
            expenseSplitMode = .splitWithOthers
            let amounts = e.splitMemberIds.compactMap { e.splits[$0] }
            let first = amounts.first ?? 0
            let tolerance = e.currency == .JPY ? 1.0 : 0.01
            let isEqual = !amounts.isEmpty && amounts.allSatisfy { abs($0 - first) <= tolerance }
            if isEqual {
                splitType = .equal
            } else {
                splitType = .custom
                for id in e.splitMemberIds {
                    if let a = e.splits[id] {
                        customAmounts[id] = e.currency == .JPY ? String(format: "%.0f", a) : String(format: "%.2f", a)
                    }
                }
            }
            if !e.splitMemberIds.contains(e.paidByMemberId) {
                payerNotInSplitOption = (e.payerEarned ?? 0) > 0.001 ? .payerEarns : .randomExtra
            }
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func addExpense() {
        addErrorMessage = nil
        customSplitError = nil
        let cleaned = amountText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else {
            addErrorMessage = L10n.string("addExpense.amountInvalid", language: languageStore.language)
            return
        }
        guard let amount = Double(cleaned), amount > 0 else {
            addErrorMessage = L10n.string("addExpense.amountInvalid", language: languageStore.language)
            return
        }
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
            id: existingExpense?.id ?? UUID().uuidString,
            description: description.trimmingCharacters(in: .whitespaces),
            amount: amount,
            category: category,
            currency: currency,
            paidByMemberId: paidByMemberId,
            date: date,
            splitMemberIds: ids,
            splits: splits,
            payerEarned: payerEarned,
            eventId: existingExpense?.eventId ?? dataStore.selectedEvent?.id
        )
        addErrorMessage = nil
        isAddingExpense = true
        if let _ = existingExpense {
            dataStore.updateExpense(expense)
            dismissKeyboard()
            withAnimation(.easeInOut(duration: 0.2)) { showSuccessToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.25)) { showSuccessToast = false }
                dismiss()
            }
        } else {
            dataStore.addExpense(expense)
            dismissKeyboard()
            description = ""
            amountText = ""
            customAmounts = [:]
            withAnimation(.easeInOut(duration: 0.2)) { showSuccessToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.25)) { showSuccessToast = false }
            }
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
    @ObservedObject private var languageStore = LanguageStore.shared

    var body: some View {
        Menu {
            ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                Button {
                    selection = cat
                } label: {
                    HStack {
                        Image(systemName: cat.icon)
                        Text(L10n.string("category.\(cat.rawValue)", language: languageStore.language))
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: selection.icon)
                Text(L10n.string("category.\(selection.rawValue)", language: languageStore.language))
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
    /// When set, only these currencies are shown (e.g. trip allows only JPY and MYR). Nil = show all.
    var allowedCurrencies: [Currency]? = nil
    
    private var currenciesToShow: [Currency] {
        if let allowed = allowedCurrencies, !allowed.isEmpty { return allowed }
        return Currency.allCases
    }
    
    var body: some View {
        Menu {
            ForEach(currenciesToShow, id: \.self) { curr in
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
    @ObservedObject private var languageStore = LanguageStore.shared

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
                Text(members.first(where: { $0.id == selection })?.name ?? L10n.string("addExpense.selectMember", language: languageStore.language))
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
