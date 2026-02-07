//
//  MembersView.swift
//  BudgetSplitter
//

import SwiftUI
import UIKit

private enum HostSheetContext {
    case afterReset
    case afterDeleteHost
}

struct MembersView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @ObservedObject private var historyStore = MemberGroupHistoryStore.shared
    @ObservedObject private var languageStore = LanguageStore.shared
    @State private var newMemberName = ""
    @State private var showGroupNameSheet = false
    @State private var groupNameInput = ""
    @State private var showHostSheet = false
    @State private var hostNameInput = ""
    /// Why the host sheet is shown: after reset (need name for first member) or after deleting the current host (add new first member).
    @State private var hostSheetContext: HostSheetContext?
    @State private var showSuccessToast = false
    @State private var successToastMessage = ""
    @State private var showErrorToast = false
    @State private var errorToastMessage = ""
    @State private var isHistoryExpanded = false
    @State private var memberToRemove: Member? = nil
    
    private let iosRed = Color(red: 1, green: 69/255, blue: 58/255)
    
    /// Members for the current context: trip's own members when a trip is selected, otherwise global list.
    private var currentMembers: [Member] {
        dataStore.members(for: dataStore.selectedEvent?.id)
    }
    
    /// Former members who left (only when a trip is selected).
    private var formerMembers: [FormerMember] {
        dataStore.formerMembers(for: dataStore.selectedEvent?.id)
    }
    
    private static let initialHostNameKey = "BudgetSplitter_initialHostName"
    private static var savedInitialHostName: String? {
        UserDefaults.standard.string(forKey: initialHostNameKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private static var hasSavedInitialHost: Bool {
        guard let s = savedInitialHostName else { return false }
        return !s.isEmpty
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Add member card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.title3)
                            .foregroundColor(.appAccent)
                        Text(L10n.string("members.title", language: languageStore.language))
                            .font(AppFonts.sectionHeader)
                            .foregroundColor(.appPrimary)
                    }
                    HStack(spacing: 10) {
                        TextField(L10n.string("members.newMemberPlaceholder", language: languageStore.language), text: $newMemberName)
                            .padding(14)
                            .background(Color.appTertiary)
                            .foregroundColor(.appPrimary)
                            .cornerRadius(10)
                            .submitLabel(.done)
                            .onSubmit { addMember() }
                        Button {
                            addMember()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.body)
                                Text(L10n.string("members.add", language: languageStore.language))
                                    .font(.subheadline.bold())
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(Color.appAccent)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appCard)
                .cornerRadius(14)

                // Member list
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.title3)
                            .foregroundColor(.appAccent)
                        Text(L10n.string("members.inGroup", language: languageStore.language))
                            .font(AppFonts.sectionHeader)
                            .foregroundColor(.appPrimary)
                    }
                    if currentMembers.isEmpty {
                        Text(L10n.string("members.addFirstHint", language: languageStore.language))
                            .font(.subheadline)
                            .foregroundColor(.appSecondary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(currentMembers) { member in
                                HStack(spacing: 12) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.appSecondary)
                                    Text(member.name)
                                        .font(.subheadline)
                                        .foregroundColor(.appPrimary)
                                    Spacer()
                                    Button {
                                        memberToRemove = member
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.subheadline)
                                            .foregroundColor(iosRed)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(14)
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

                // Member History (collapsible)
                if !currentMembers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { isHistoryExpanded.toggle() }
                        } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .font(.title3)
                                .foregroundColor(.appAccent)
                            Text(L10n.string("members.history", language: languageStore.language))
                                .font(AppFonts.sectionHeader)
                                .foregroundColor(.appPrimary)
                                Spacer()
                                Image(systemName: isHistoryExpanded ? "chevron.up" : "chevron.down")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        if isHistoryExpanded {
                            VStack(spacing: 8) {
                                ForEach(currentMembers.sorted(by: { ($0.joinedAt ?? .distantPast) < ($1.joinedAt ?? .distantPast) })) { member in
                                    HStack(spacing: 12) {
                                        Text(member.name)
                                            .font(.subheadline)
                                            .foregroundColor(.appPrimary)
                                        Spacer()
                                        if let date = member.joinedAt {
                                            Text(String(format: L10n.string("members.joinedOn", language: languageStore.language), date.formatted(date: .abbreviated, time: .omitted)))
                                                .font(.caption)
                                                .foregroundColor(.appSecondary)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.appTertiary)
                                    .cornerRadius(10)
                                }
                                ForEach(formerMembers.sorted(by: { $0.leftAt > $1.leftAt })) { former in
                                    HStack(spacing: 12) {
                                        Text(former.name)
                                            .font(.subheadline)
                                            .foregroundColor(.appSecondary)
                                        Spacer()
                                        Text(String(format: L10n.string("members.leftOn", language: languageStore.language), former.leftAt.formatted(date: .abbreviated, time: .omitted)))
                                            .font(.caption)
                                            .foregroundColor(.appSecondary)
                                        if !currentMembers.contains(where: { $0.id == former.id }) {
                                            Button(L10n.string("members.inviteBack", language: languageStore.language)) {
                                                if let eid = dataStore.selectedEvent?.id {
                                                    dataStore.addFormerMemberBack(former, eventId: eid)
                                                }
                                            }
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(.appAccent)
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.appTertiary.opacity(0.7))
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
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    if showSuccessToast {
                        successToast
                    }
                    if showErrorToast {
                        errorToast
                    }
                }
                .padding(.top, 12)
            }
            .navigationTitle(dataStore.selectedEvent?.name ?? "💰 \(L10n.string("members.navTitle", language: languageStore.language))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BackToTripsButton()
                        .environmentObject(dataStore)
                }
                ToolbarItem(placement: .principal) {
                    Text(dataStore.selectedEvent?.name ?? "💰 \(L10n.string("members.navTitle", language: languageStore.language))")
                        .font(AppFonts.tripTitle)
                        .foregroundColor(.primary)
                }
            }
            .keyboardDoneButton()
            .sheet(isPresented: $showGroupNameSheet) {
                groupNameSheet
            }
            .sheet(isPresented: $showHostSheet) {
                hostSheet
            }
            .alert(L10n.string("members.removeConfirmTitle", language: languageStore.language), isPresented: Binding(get: { memberToRemove != nil }, set: { if !$0 { memberToRemove = nil } })) {
                Button(L10n.string("common.cancel", language: languageStore.language), role: .cancel) {
                    memberToRemove = nil
                }
                Button(L10n.string("members.delete", language: languageStore.language), role: .destructive) {
                    if let member = memberToRemove {
                        let isFirst = currentMembers.first?.id == member.id
                        dataStore.removeMember(id: member.id, eventId: dataStore.selectedEvent?.id)
                        memberToRemove = nil
                        if isFirst {
                            hostSheetContext = .afterDeleteHost
                            hostNameInput = ""
                            showHostSheet = true
                        }
                    }
                }
            } message: {
                if let member = memberToRemove {
                    Text(L10n.string("members.removeConfirmMessage", language: languageStore.language).replacingOccurrences(of: "%@", with: member.name))
                }
            }
    }
    
    private var groupNameSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(L10n.string("members.nameThisGroupFooter", language: languageStore.language))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextField(L10n.string("members.groupNamePlaceholder", language: languageStore.language), text: $groupNameInput)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                Spacer()
            }
            .padding()
            .background(Color.appBackground)
            .navigationTitle(L10n.string("members.nameThisGroup", language: languageStore.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel", language: languageStore.language)) {
                        showGroupNameSheet = false
                    }
                    .foregroundColor(iosRed)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.save", language: languageStore.language)) {
                        let name = groupNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        MemberGroupHistoryStore.shared.saveCurrentGroup(
                            members: currentMembers,
                            expenses: dataStore.expenses,
                            label: name.isEmpty ? nil : name
                        )
                        showGroupNameSheet = false
                        if let saved = MembersView.savedInitialHostName, !saved.isEmpty {
                            dataStore.resetAll(firstMemberName: saved)
                        } else {
                            hostSheetContext = .afterReset
                            hostNameInput = ""
                            showHostSheet = true
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color.appAccent)
                }
            }
        }
    }
    
    private var hostSheet: some View {
        let isAfterDeleteHost = hostSheetContext == .afterDeleteHost
        return NavigationStack {
            VStack(spacing: 16) {
                Text(isAfterDeleteHost
                     ? L10n.string("members.whoDoYouWantAsHost", language: languageStore.language)
                     : L10n.string("members.whoIsHost", language: languageStore.language))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextField(L10n.string("members.hostNamePlaceholder", language: languageStore.language), text: $hostNameInput)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .autocapitalization(.words)
                Spacer()
            }
            .padding()
            .background(Color.appBackground)
            .navigationTitle(isAfterDeleteHost ? L10n.string("members.addNewHost", language: languageStore.language) : L10n.string("members.whoIsHostTitle", language: languageStore.language))
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.done", language: languageStore.language)) {
                        let name = hostNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalName = name.isEmpty ? "Member 1" : name
                        switch hostSheetContext {
                        case .afterReset:
                            UserDefaults.standard.set(finalName, forKey: MembersView.initialHostNameKey)
                            dataStore.resetAll(firstMemberName: finalName)
                        case .afterDeleteHost:
                            UserDefaults.standard.set(finalName, forKey: MembersView.initialHostNameKey)
                            dataStore.addMemberAsFirst(finalName, eventId: dataStore.selectedEvent?.id)
                        case .none:
                            break
                        }
                        showHostSheet = false
                        hostSheetContext = nil
                        hostNameInput = ""
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color.appAccent)
                    .disabled(hostNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var successToast: some View {
        Text(successToastMessage)
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
    
    private var errorToast: some View {
        Text(errorToastMessage)
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(iosRed)
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .zIndex(100)
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func saveCurrentGroupToHistory(label: String? = nil) {
        MemberGroupHistoryStore.shared.saveCurrentGroup(
            members: currentMembers,
            expenses: dataStore.expenses,
            label: label
        )
    }

    private func addMember() {
        let name = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let isDuplicate = currentMembers.contains { $0.name.lowercased() == name.lowercased() }
        if isDuplicate {
            errorToastMessage = L10n.string("members.duplicateName", language: languageStore.language)
            withAnimation(.easeInOut(duration: 0.2)) { showErrorToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut(duration: 0.25)) { showErrorToast = false }
            }
            return
        }
        dataStore.addMember(name, eventId: dataStore.selectedEvent?.id)
        dismissKeyboard()
        newMemberName = ""
        successToastMessage = L10n.string("members.successAdded", language: languageStore.language)
        withAnimation(.easeInOut(duration: 0.2)) { showSuccessToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.25)) { showSuccessToast = false }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let proposedWidth = proposal.width ?? 400
        let maxWidth = proposedWidth.isFinite && proposedWidth > 0 ? proposedWidth : 400
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        
        return (CGSize(width: max(maxWidth, x), height: y + rowHeight), positions)
    }
}

struct SummaryCard: View {
    @ObservedObject var dataStore: BudgetDataStore
    @ObservedObject private var languageStore = LanguageStore.shared
    
    private func formatMoney(_ amount: Double, _ currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = currency.decimals
        formatter.minimumFractionDigits = currency.decimals
        let str = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "\(currency.symbol)\(str)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let total = dataStore.totalSpent(currency: .JPY)
            Text(String(format: L10n.string("members.totalSpent", language: languageStore.language), "JPY", formatMoney(total, .JPY)))
                .font(.headline.bold())
                .foregroundColor(.appPrimary)
            
            let memberTotals = dataStore.members(for: dataStore.selectedEvent?.id)
                .map { ($0, dataStore.memberTotal(memberId: $0.id, currency: .JPY)) }
                .filter { $0.1 > 0 }
                .sorted { $0.1 > $1.1 }
            
            ForEach(memberTotals.prefix(5), id: \.0.id) { member, amount in
                HStack {
                    Text(member.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.appPrimary)
                    Spacer()
                    Text(formatMoney(amount, .JPY))
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                        .monospacedDigit()
                }
                .padding(.vertical, 8)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color.appSeparator),
                    alignment: .bottom
                )
            }
            if memberTotals.count > 5 {
                Text(String(format: L10n.string("members.moreMembers", language: languageStore.language), memberTotals.count - 5))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color.appCard)
        .cornerRadius(12)
        
        // By Category
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("members.byCategory", language: languageStore.language))
                .font(.headline.bold())
                .foregroundColor(.appPrimary)
            
            let categories = dataStore.categoryTotals(currency: .JPY)
                .sorted { $0.value > $1.value }
            
            ForEach(categories, id: \.key) { category, amount in
                HStack {
                    Image(systemName: category.icon)
                    Text(category.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.appPrimary)
                    Spacer()
                    Text(formatMoney(amount, .JPY))
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                        .monospacedDigit()
                }
                .padding(.vertical, 8)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color.appSeparator),
                    alignment: .bottom
                )
            }
        }
        .padding()
        .background(Color.appCard)
        .cornerRadius(12)
    }
}

#Preview {
    MembersView()
        .environmentObject(BudgetDataStore())
}
