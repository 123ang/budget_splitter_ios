//
//  Event.swift
//  Xsplitter
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
    /// Main currency for this trip (overview and totals). Default JPY.
    var mainCurrencyCode: String?
    /// Optional sub currency; user can enter expenses in main or sub. When set, exchange rate is used to convert to main. (Legacy single sub; see subCurrencyRatesByCode for 1–3 subs.)
    var subCurrencyCode: String?
    /// Exchange rate: 1 sub currency = this many main. (Legacy; see subCurrencyRatesByCode.)
    var subCurrencyRate: Double?
    /// Up to 3 sub-currencies with rate to main: 1 sub = value main. Keys = currency codes. Nil/empty = use legacy subCurrencyCode/subCurrencyRate.
    var subCurrencyRatesByCode: [String: Double]?
    /// Members for this session only. Not shared with other sessions.
    var members: [Member]
    /// Members who left this session (for history: "X left on …").
    var formerMembers: [FormerMember]
    /// Type of session: meal, event, trip, party, or other.
    var sessionType: SessionType
    /// Custom type label when sessionType == .other; user-filled.
    var sessionTypeCustom: String?
    
    var isOngoing: Bool { endedAt == nil }
    
    /// Main currency for display (overview symbol). Default JPY.
    var mainCurrency: Currency { Currency(rawValue: mainCurrencyCode ?? "JPY") ?? .JPY }
    /// Sub currency if set (legacy single; prefer subCurrencies).
    var subCurrency: Currency? { subCurrencyCode.flatMap { Currency(rawValue: $0) } }
    /// Sub currencies with rates: 1 sub = rate main. Up to 3. Uses subCurrencyRatesByCode when set, else legacy single.
    var subCurrencies: [(currency: Currency, rate: Double)] {
        if let dict = subCurrencyRatesByCode, !dict.isEmpty {
            return dict.compactMap { code, rate in
                guard rate > 0, let c = Currency(rawValue: code), c != mainCurrency else { return nil }
                return (c, rate)
            }
        }
        if let sub = subCurrency, let rate = subCurrencyRate, rate > 0 { return [(sub, rate)] }
        return []
    }
    
    /// Currencies allowed for this session; nil = all.
    var allowedCurrencies: Set<Currency>? {
        guard let codes = currencyCodes, !codes.isEmpty else { return nil }
        let set = Set(codes.compactMap { Currency(rawValue: $0) })
        return set.isEmpty ? nil : set
    }
    
    init(id: String = UUID().uuidString, name: String, createdAt: Date = Date(), endedAt: Date? = nil, memberIds: [String]? = nil, currencyCodes: [String]? = nil, mainCurrencyCode: String? = nil, subCurrencyCode: String? = nil, subCurrencyRate: Double? = nil, subCurrencyRatesByCode: [String: Double]? = nil, members: [Member] = [], formerMembers: [FormerMember] = [], sessionType: SessionType = .trip, sessionTypeCustom: String? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.endedAt = endedAt
        self.memberIds = memberIds
        self.currencyCodes = currencyCodes
        self.mainCurrencyCode = mainCurrencyCode
        self.subCurrencyCode = subCurrencyCode
        self.subCurrencyRate = subCurrencyRate
        self.subCurrencyRatesByCode = subCurrencyRatesByCode
        self.members = members
        self.formerMembers = formerMembers
        self.sessionType = sessionType
        self.sessionTypeCustom = sessionTypeCustom
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, createdAt, endedAt, memberIds, currencyCodes, mainCurrencyCode, subCurrencyCode, subCurrencyRate, subCurrencyRatesByCode, members, formerMembers, sessionType, sessionTypeCustom
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
        memberIds = try c.decodeIfPresent([String].self, forKey: .memberIds)
        currencyCodes = try c.decodeIfPresent([String].self, forKey: .currencyCodes)
        mainCurrencyCode = try c.decodeIfPresent(String.self, forKey: .mainCurrencyCode)
        subCurrencyCode = try c.decodeIfPresent(String.self, forKey: .subCurrencyCode)
        subCurrencyRate = try c.decodeIfPresent(Double.self, forKey: .subCurrencyRate)
        var decodedRates = try c.decodeIfPresent([String: Double].self, forKey: .subCurrencyRatesByCode)
        if decodedRates == nil, let subCode = subCurrencyCode, let rate = subCurrencyRate, rate > 0 {
            decodedRates = [subCode: rate]
        }
        subCurrencyRatesByCode = decodedRates
        members = (try? c.decode([Member].self, forKey: .members)) ?? []
        formerMembers = (try? c.decode([FormerMember].self, forKey: .formerMembers)) ?? []
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
        try c.encodeIfPresent(mainCurrencyCode, forKey: .mainCurrencyCode)
        try c.encodeIfPresent(subCurrencyCode, forKey: .subCurrencyCode)
        try c.encodeIfPresent(subCurrencyRate, forKey: .subCurrencyRate)
        try c.encodeIfPresent(subCurrencyRatesByCode, forKey: .subCurrencyRatesByCode)
        try c.encode(members, forKey: .members)
        try c.encode(formerMembers, forKey: .formerMembers)
        try c.encode(sessionType, forKey: .sessionType)
        try c.encodeIfPresent(sessionTypeCustom, forKey: .sessionTypeCustom)
    }
}
