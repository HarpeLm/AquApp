//
//  KeychainManager.swift
//  AquApp
//
//  Created by Fabian Dargaud on 09/09/2026.
//


import Foundation
import Security

/// Coffre-fort chiffré iOS — remplace UserDefaults pour tout ce qui est sensible.
final class KeychainManager {

    static let shared = KeychainManager()
    private init() {}

    private let service = "com.fabian.dargaud.AquApp"

    // MARK: - Écriture

    func set(_ value: Bool, forKey key: String) {
        set(Data([value ? 1 : 0]), forKey: key)
    }

    func set(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        set(data, forKey: key)
    }

    func set(_ value: Double, forKey key: String) {
        set(withUnsafeBytes(of: value) { Data($0) }, forKey: key)
    }

    private func set(_ data: Data, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ] as CFDictionary, nil)
    }

    // MARK: - Lecture

    func getBool(forKey key: String) -> Bool? {
        guard let data = get(forKey: key), let byte = data.first else { return nil }
        return byte == 1
    }

    func getString(forKey key: String) -> String? {
        guard let data = get(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func getDouble(forKey key: String) -> Double? {
        guard let data = get(forKey: key) else { return nil }
        return data.withUnsafeBytes { $0.load(as: Double.self) }
    }

    private func get(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    // MARK: - Suppression

    func delete(forKey key: String) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ] as CFDictionary)
    }
}