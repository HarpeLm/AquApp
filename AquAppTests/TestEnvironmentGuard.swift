import Foundation
import Security
import XCTest
@testable import AquApp

/// Les tests unitaires tournent DANS l'app installée sur le simulateur et partagent
/// ses UserDefaults, son App Group et son Keychain. Cette classe (NSPrincipalClass du
/// bundle de tests) photographie ces stockages avant la suite et les restaure après :
/// l'app de dev retrouve son objectif, son prénom, son XP, ses séries…
@objc(TestEnvironmentGuard)
final class TestEnvironmentGuard: NSObject, XCTestObservation {

    private var defaultsSnapshot: [String: Any]?
    private var appGroupSnapshot: [String: Any]?
    private var keychainSnapshot: [[String: Any]] = []

    private let appDomain = Bundle.main.bundleIdentifier ?? "com.fabian.dargaud.AquApp"
    private let appGroup = WidgetBridge.appGroup

    override init() {
        super.init()
        XCTestObservationCenter.shared.addTestObserver(self)
    }

    func testBundleWillStart(_ testBundle: Bundle) {
        defaultsSnapshot = UserDefaults.standard.persistentDomain(forName: appDomain)
        appGroupSnapshot = UserDefaults(suiteName: appGroup)?.persistentDomain(forName: appGroup)
        keychainSnapshot = Self.keychainItems()
    }

    func testBundleDidFinish(_ testBundle: Bundle) {
        restore(defaultsSnapshot, in: .standard, domain: appDomain)
        if let groupDefaults = UserDefaults(suiteName: appGroup) {
            restore(appGroupSnapshot, in: groupDefaults, domain: appGroup)
        }
        Self.restoreKeychain(keychainSnapshot)
    }

    private func restore(_ snapshot: [String: Any]?, in defaults: UserDefaults, domain: String) {
        if let snapshot {
            defaults.setPersistentDomain(snapshot, forName: domain)
        } else {
            defaults.removePersistentDomain(forName: domain)
        }
        defaults.synchronize()
    }

    // MARK: - Keychain

    private static var serviceQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: KeychainManager.service]
    }

    private static func keychainItems() -> [[String: Any]] {
        var query = serviceQuery
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        query[kSecReturnAttributes as String] = true
        query[kSecReturnData as String] = true
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return [] }
        return result as? [[String: Any]] ?? []
    }

    private static func restoreKeychain(_ items: [[String: Any]]) {
        SecItemDelete(serviceQuery as CFDictionary)
        for item in items {
            guard let account = item[kSecAttrAccount as String],
                  let data = item[kSecValueData as String] else { continue }
            var add = serviceQuery
            add[kSecAttrAccount as String] = account
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = item[kSecAttrAccessible as String]
                ?? kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}
