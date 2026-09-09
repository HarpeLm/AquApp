//
//  PremiumManager.swift
//  AquApp
//
//  Created by Fabian Dargaud on 09/09/2026.
//


import Foundation
import Combine

/// Source de vérité UNIQUE du statut Premium — stockée en Keychain.
/// Migre automatiquement l'ancienne valeur UserDefaults une seule fois,
/// puis supprime la copie plist (non spoofable).
final class PremiumManager: ObservableObject {

    static let shared = PremiumManager()
    private let key = "isPremiumUser"

    @Published private(set) var isPremium: Bool

    private init() {
        if let stored = KeychainManager.shared.getBool(forKey: key) {
            isPremium = stored
        } else {
            let legacy = UserDefaults.standard.bool(forKey: key)
            isPremium = legacy
            if legacy { KeychainManager.shared.set(true, forKey: key) }
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func set(_ value: Bool) {
        KeychainManager.shared.set(value, forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
        isPremium = value
    }

    /// Réservé aux tests : remet le statut à un état connu.
    func resetForTests(_ value: Bool = false) {
        set(value)
    }
}