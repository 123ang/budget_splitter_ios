//
//  AuthService.swift
//  BudgetSplitter
//
//  VPS mode authentication. Uses UserDefaults for token (upgrade to Keychain for production).
//

import Combine
import Foundation
import UIKit

struct User: Codable {
    let id: String
    let email: String?
    let phone: String?
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case phone
        case displayName = "display_name"
    }
}

struct AuthResponse: Codable {
    let user: User
    let token: String
}

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    private let tokenKey = "BudgetSplitter_auth_token"
    private let userKey = "BudgetSplitter_current_user"

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false

    private init() {
        loadStoredUser()
    }

    func getToken() -> String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    private func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
    }

    private func removeToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }

    private func loadStoredUser() {
        if let data = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            currentUser = user
            isAuthenticated = getToken() != nil
        }
    }

    private func saveUser(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
        currentUser = user
        isAuthenticated = true
    }

    private func clearUser() {
        UserDefaults.standard.removeObject(forKey: userKey)
        currentUser = nil
        isAuthenticated = false
    }

    func login(emailOrPhone: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let url = URL(string: "\(AppConfig.apiBaseURL)/auth/login")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode([
            "emailOrPhone": emailOrPhone,
            "password": password,
            "deviceName": UIDevice.current.name
        ])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.networkError("Invalid response") }

        if http.statusCode != 200 {
            let err = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error ?? "Login failed"
            throw APIError.serverError(err)
        }

        let auth: AuthResponse = try JSONDecoder.apiDecoder.decode(AuthResponse.self, from: data)
        saveToken(auth.token)
        saveUser(auth.user)
    }

    func register(email: String?, phone: String?, password: String, displayName: String) async throws {
        isLoading = true
        defer { isLoading = false }

        var params: [String: Any] = ["password": password, "displayName": displayName]
        if let e = email, !e.isEmpty { params["email"] = e }
        if let p = phone, !p.isEmpty { params["phone"] = p }

        let url = URL(string: "\(AppConfig.apiBaseURL)/auth/register")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: params)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.networkError("Invalid response") }

        if http.statusCode != 201 {
            let err = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error ?? "Registration failed"
            throw APIError.serverError(err)
        }

        let auth: AuthResponse = try JSONDecoder.apiDecoder.decode(AuthResponse.self, from: data)
        saveToken(auth.token)
        saveUser(auth.user)
    }

    func logout() {
        Task {
            if let token = getToken() {
                var req = URLRequest(url: URL(string: "\(AppConfig.apiBaseURL)/auth/logout")!)
                req.httpMethod = "POST"
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                _ = try? await URLSession.shared.data(for: req)
            }
        }
        removeToken()
        clearUser()
    }
}

enum APIError: LocalizedError {
    case unauthorized
    case serverError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Please log in again"
        case .serverError(let m): return m
        case .networkError(let m): return "Network: \(m)"
        }
    }
}

struct APIErrorResponse: Codable {
    let error: String
}

extension JSONDecoder {
    static var apiDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
