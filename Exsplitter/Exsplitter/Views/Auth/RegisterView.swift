//
//  RegisterView.swift
//  Xsplitter
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
                            Text(L10n.string("auth.email")).tag(true)
                            Text(L10n.string("auth.phone")).tag(false)
                        }
                        .pickerStyle(.segmented)

                        TextField(L10n.string("auth.displayName"), text: $displayName)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.appTertiary)
                            .foregroundColor(.appPrimary)
                            .cornerRadius(12)

                        if useEmail {
                            TextField(L10n.string("auth.email"), text: $email)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.appTertiary)
                                .foregroundColor(.appPrimary)
                                .cornerRadius(12)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        } else {
                            TextField(L10n.string("auth.phone"), text: $phone)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.appTertiary)
                                .foregroundColor(.appPrimary)
                                .cornerRadius(12)
                                .keyboardType(.phonePad)
                        }

                        SecureField(L10n.string("auth.passwordMin"), text: $password)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.appTertiary)
                            .foregroundColor(.appPrimary)
                            .cornerRadius(12)

                        SecureField(L10n.string("auth.confirmPassword"), text: $confirmPassword)
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
                                Text(L10n.string("auth.registerButton"))
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
            .navigationTitle(L10n.string("auth.register"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel")) { dismiss() }
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
            errorMessage = L10n.string("auth.passwordsDoNotMatch")
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
                errorMessage = (error as? LocalizedError)?.errorDescription ?? L10n.string("auth.registrationFailed")
            }
        }
    }
}

#Preview {
    RegisterView()
}
