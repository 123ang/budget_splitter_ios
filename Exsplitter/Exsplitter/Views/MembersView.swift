//
//  MembersView.swift
//  BudgetSplitter
//

import SwiftUI
import UIKit

struct MembersView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @ObservedObject private var historyStore = MemberGroupHistoryStore.shared
    @State private var newMemberName = ""
    @State private var showResetOptions = false
    @State private var showGroupNameSheet = false
    @State private var groupNameInput = ""
    @State private var showHostSheet = false
    @State private var hostNameInput = ""
    @State private var showRenameSheet = false
    @State private var renameGroupId: UUID?
    @State private var renameInput = ""
    @State private var showSuccessToast = false
    @State private var successToastMessage = "Successfully added"
    @State private var showErrorToast = false
    @State private var errorToastMessage = ""
    
    private let iosBlue = Color(red: 10/255, green: 132/255, blue: 1)
    private let iosRed = Color(red: 1, green: 69/255, blue: 58/255)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Members management card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Members")
                            .font(.headline.bold())
                            .foregroundColor(.appPrimary)
                        
                        HStack(spacing: 8) {
                            TextField("e.g. John", text: $newMemberName)
                                .padding(10)
                                .background(Color.appTertiary)
                                .foregroundColor(.appPrimary)
                                .cornerRadius(8)
                                .submitLabel(.done)
                                .onSubmit { addMember() }
                            Button {
                                addMember()
                            } label: {
                                Text("Add")
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(iosBlue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        
                        FlowLayout(spacing: 4) {
                            ForEach(dataStore.members) { member in
                                HStack(spacing: 6) {
                                    Text(member.name)
                                        .font(.caption)
                                        .foregroundColor(.appPrimary)
                                    Button {
                                        dataStore.removeMember(id: member.id)
                                    } label: {
                                        Text("Delete")
                                            .font(.caption)
                                            .foregroundColor(iosRed)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.appTertiary)
                                .cornerRadius(16)
                            }
                        }
                        
                        Button {
                            showResetOptions = true
                        } label: {
                            Text("Reset All Data")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(iosRed)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.top, 16)
                    }
                    .padding()
                    .background(Color.appCard)
                    .cornerRadius(12)
                    
                    // Saved groups (history) – add a group from past hangouts
                    if !historyStore.groups.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Saved groups")
                                .font(.headline.bold())
                                .foregroundColor(.appPrimary)
                            Text("Add a group from history instead of adding members one by one.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(historyStore.groups) { group in
                                HStack {
                                    NavigationLink {
                                        SavedGroupDetailView(group: group)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(group.label)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.appPrimary)
                                            Text("\(group.displayMemberNames.count) members • \(group.shortDate)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                    Button {
                                        renameGroupId = group.id
                                        renameInput = group.label
                                        showRenameSheet = true
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Button {
                                        addGroupFromHistory(group)
                                    } label: {
                                        Text("Add group")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(iosBlue)
                                            .cornerRadius(8)
                                    }
                                    Button {
                                        historyStore.removeGroup(id: group.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundColor(iosRed)
                                    }
                                }
                                .padding(12)
                                .background(Color.appTertiary)
                                .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(Color.appCard)
                        .cornerRadius(12)
                    }
                }
                .padding()
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
            .navigationTitle("💰 Budget Splitter")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .confirmationDialog("Reset All Data?", isPresented: $showResetOptions, titleVisibility: .visible) {
                Button("Remember this group") {
                    showGroupNameSheet = true
                    groupNameInput = ""
                }
                Button("Just reset (don't save)") {
                    showHostSheet = true
                    hostNameInput = ""
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Remember this group saves members and expenses to history so you can add them again later. Just reset clears everything without saving.")
            }
            .sheet(isPresented: $showGroupNameSheet) {
                groupNameSheet
            }
            .sheet(isPresented: $showHostSheet) {
                hostSheet
            }
            .sheet(isPresented: $showRenameSheet) {
                renameGroupSheet
            }
        }
    }
    
    private var renameGroupSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Group name", text: $renameInput)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .autocapitalization(.words)
                Spacer()
            }
            .padding()
            .background(Color.appBackground)
            .navigationTitle("Rename group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showRenameSheet = false
                        renameGroupId = nil
                    }
                    .foregroundColor(iosRed)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let id = renameGroupId {
                            historyStore.updateGroupLabel(id: id, newLabel: renameInput)
                        }
                        showRenameSheet = false
                        renameGroupId = nil
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(iosBlue)
                    .disabled(renameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var groupNameSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Give this group a name so you can find it later (e.g. Tokyo Trip, Dinner with Friends).")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextField("e.g. Tokyo Trip", text: $groupNameInput)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                Spacer()
            }
            .padding()
            .background(Color.appBackground)
            .navigationTitle("Name this group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showGroupNameSheet = false
                    }
                    .foregroundColor(iosRed)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let name = groupNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        MemberGroupHistoryStore.shared.saveCurrentGroup(
                            members: dataStore.members,
                            expenses: dataStore.expenses,
                            label: name.isEmpty ? nil : name
                        )
                        showGroupNameSheet = false
                        showHostSheet = true
                        hostNameInput = ""
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(iosBlue)
                }
            }
        }
    }
    
    private var hostSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Who is the host? Enter the first member's name. This person will be the only member until you add more.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextField("e.g. John", text: $hostNameInput)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .autocapitalization(.words)
                Spacer()
            }
            .padding()
            .background(Color.appBackground)
            .navigationTitle("Who is the host?")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let name = hostNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        dataStore.resetAll(firstMemberName: name.isEmpty ? "Member 1" : name)
                        showHostSheet = false
                        hostNameInput = ""
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(iosBlue)
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
            members: dataStore.members,
            expenses: dataStore.expenses,
            label: label
        )
    }

    private func addGroupFromHistory(_ group: SavedMemberGroup) {
        Task {
            do {
                try await dataStore.addMembersFromHistory(names: group.memberNames)
                await MainActor.run {
                    successToastMessage = "Added \(group.memberNames.count) members"
                    withAnimation(.easeInOut(duration: 0.2)) { showSuccessToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.25)) { showSuccessToast = false }
                        successToastMessage = "Successfully added"
                    }
                }
            } catch {
                await MainActor.run {
                    errorToastMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to add members"
                    withAnimation(.easeInOut(duration: 0.2)) { showErrorToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeOut(duration: 0.25)) { showErrorToast = false }
                    }
                }
            }
        }
    }

    private func addMember() {
        let name = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let isDuplicate = dataStore.members.contains { $0.name.lowercased() == name.lowercased() }
        if isDuplicate {
            errorToastMessage = "A member with this name already exists."
            withAnimation(.easeInOut(duration: 0.2)) { showErrorToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut(duration: 0.25)) { showErrorToast = false }
            }
            return
        }
        Task {
            do {
                try await dataStore.addMember(name)
                await MainActor.run {
                    dismissKeyboard()
                    newMemberName = ""
                    successToastMessage = "Successfully added"
                    withAnimation(.easeInOut(duration: 0.2)) { showSuccessToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.25)) { showSuccessToast = false }
                    }
                }
            } catch {
                await MainActor.run {
                    errorToastMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to add member"
                    withAnimation(.easeInOut(duration: 0.2)) { showErrorToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeOut(duration: 0.25)) { showErrorToast = false }
                    }
                }
            }
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
            Text("JPY — Total Spent: \(formatMoney(total, .JPY))")
                .font(.headline.bold())
                .foregroundColor(.appPrimary)
            
            let memberTotals = dataStore.members
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
                Text("+ \(memberTotals.count - 5) more members")
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
            Text("By Category")
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
