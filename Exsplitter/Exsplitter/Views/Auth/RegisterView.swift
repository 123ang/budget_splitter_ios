//
//  RegisterView.swift
//  BudgetSplitter
//
//  VPS mode - Registration
//

import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var auth = AuthService.shared
    @State private var useEmail = true
    @State private var email = ""
    @State private var phone = ""
    @State private var displayName = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        Picker("", selection: $useEmail) {
                            Text("Email").tag(true)
                            Text("Phone").tag(false)
                        }
                        .pickerStyle(.segmented)

                        TextField("Display Name", text: $displayName)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.appTertiary)
                            .foregroundColor(.appPrimary)
                            .cornerRadius(12)

                        if useEmail {
                            TextField("Email", text: $email)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.appTertiary)
                                .foregroundColor(.appPrimary)
                                .cornerRadius(12)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        } else {
                            TextField("Phone", text: $phone)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.appTertiary)
                                .foregroundColor(.appPrimary)
                                .cornerRadius(12)
                                .keyboardType(.phonePad)
                        }

                        SecureField("Password (min 8)", text: $password)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.appTertiary)
                            .foregroundColor(.appPrimary)
                            .cornerRadius(12)

                        SecureField("Confirm Password", text: $confirmPassword)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.appTertiary)
                            .foregroundColor(.appPrimary)
                            .cornerRadius(12)

                        if let err = errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        Button {
                            performRegister()
                        } label: {
                            if auth.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Create Account")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(!isValid)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Register")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.appAccent)
                }
            }
            .keyboardDoneButton()
        }
    }

    private var isValid: Bool {
        !displayName.isEmpty &&
        (useEmail ? !email.isEmpty : !phone.isEmpty) &&
        password.count >= 8 &&
        password == confirmPassword
    }

    private func performRegister() {
        errorMessage = nil
        if password != confirmPassword {
            errorMessage = "Passwords do not match"
            return
        }
        Task {
            do {
                try await auth.register(
                    email: useEmail ? email : nil,
                    phone: useEmail ? nil : phone,
                    password: password,
                    displayName: displayName
                )
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Registration failed"
            }
        }
    }
}

#Preview {
    RegisterView()
}
