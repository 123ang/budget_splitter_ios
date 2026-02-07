//
//  LoginView.swift
//  BudgetSplitter
//
//  VPS mode - Login screen
//

import SwiftUI

struct LoginView: View {
    @StateObject private var auth = AuthService.shared
    @State private var emailOrPhone = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("💰")
                            .font(.system(size: 56))
                        Text("Budget Splitter")
                            .font(.title.bold())
                            .foregroundColor(.appPrimary)
                        Text("Sign in to sync with cloud")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 48)

                    Spacer()

                    VStack(spacing: 16) {
                        TextField("Email or Phone", text: $emailOrPhone)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.appTertiary)
                            .foregroundColor(.appPrimary)
                            .cornerRadius(12)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)

                        SecureField("Password", text: $password)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.appTertiary)
                            .foregroundColor(.appPrimary)
                            .cornerRadius(12)

                        if let err = errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            performLogin()
                        } label: {
                            if auth.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Log In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.appAccent)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(auth.isLoading || emailOrPhone.isEmpty || password.isEmpty)

                        Button {
                            showRegister = true
                        } label: {
                            Text("Create account")
                                .font(.subheadline)
                                .foregroundColor(Color.appAccent)
                        }
                    }
                    .padding(.horizontal, 24)
                    Spacer()
                }
            }
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
            .keyboardDoneButton()
        }
    }

    private func performLogin() {
        errorMessage = nil
        Task {
            do {
                try await auth.login(emailOrPhone: emailOrPhone, password: password)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Login failed"
            }
        }
    }
}

#Preview {
    LoginView()
}
