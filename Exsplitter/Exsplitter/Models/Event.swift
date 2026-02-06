//
//  Event.swift
//  Exsplitter
//

import Foundation

/// Session type when creating a session: meal, event, trip, party, or other (with optional custom label).
enum SessionType: String, Codable, CaseIterable {
    case meal
    case event
    case trip
    case party
    case other
}

/// A session (meal, event, trip, party, or other) that groups expenses.
/// Each session has its own members list so data is not shared between sessions.
struct Event: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var createdAt: Date
    /// When set, the session is ended (archived). Nil = ongoing.
    var endedAt: Date?
    /// When set, only these member IDs participate (legacy filter). Prefer using `members` for per-session data.
    var memberIds: [String]?
    /// When set, session only shows expenses in these currencies. Nil = all currencies.
    var currencyCodes: [String]?
    /// Members for this session only. Not shared with other sessions.
    var members: [Member]
    /// Type of session: meal, event, trip, party, or other.
    var sessionType: SessionType
    /// Custom type label when sessionType == .other; user-filled.
    var sessionTypeCustom: String?
    
    var isOngoing: Bool { endedAt == nil }
    
    /// Currencies allowed for this session; nil = all.
    var allowedCurrencies: Set<Currency>? {
        guard let codes = currencyCodes, !codes.isEmpty else { return nil }
        let set = Set(codes.compactMap { Currency(rawValue: $0) })
        return set.isEmpty ? nil : set
    }
    
    init(id: String = UUID().uuidString, name: String, createdAt: Date = Date(), endedAt: Date? = nil, memberIds: [String]? = nil, currencyCodes: [String]? = nil, members: [Member] = [], sessionType: SessionType = .trip, sessionTypeCustom: String? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.endedAt = endedAt
        self.memberIds = memberIds
        self.currencyCodes = currencyCodes
        self.members = members
        self.sessionType = sessionType
        self.sessionTypeCustom = sessionTypeCustom
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, createdAt, endedAt, memberIds, currencyCodes, members, sessionType, sessionTypeCustom
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
        memberIds = try c.decodeIfPresent([String].self, forKey: .memberIds)
        currencyCodes = try c.decodeIfPresent([String].self, forKey: .currencyCodes)
        members = (try? c.decode([Member].self, forKey: .members)) ?? []
        sessionType = (try? c.decode(SessionType.self, forKey: .sessionType)) ?? .trip
        sessionTypeCustom = try c.decodeIfPresent(String.self, forKey: .sessionTypeCustom)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(endedAt, forKey: .endedAt)
        try c.encodeIfPresent(memberIds, forKey: .memberIds)
        try c.encodeIfPresent(currencyCodes, forKey: .currencyCodes)
        try c.encode(members, forKey: .members)
        try c.encode(sessionType, forKey: .sessionType)
        try c.encodeIfPresent(sessionTypeCustom, forKey: .sessionTypeCustom)
    }
}
