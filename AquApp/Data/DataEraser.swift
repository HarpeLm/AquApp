import Foundation
import UserNotifications

// MARK: - DataEraser
// « Supprimer mes données » (droit à l'effacement, RGPD art. 17).
// Efface tout ce qu'AquApp conserve sur l'iPhone, puis remet l'app dans l'état
// d'un premier lancement (l'onboarding réapparaît) :
//   • SwiftData : eau, alcool, historique des jours
//   • Trousseau : profil, prénom, séries, XP, succès… (il survit à la désinstallation)
//   • UserDefaults de l'app et de l'App Group (widget) : réglages, défis du jour, XP par jour
//   • photo de profil, rappels programmés
//   • en option : l'eau qu'AquApp a écrite dans Santé
// Seul le statut Premium est conservé : c'est un achat, pas une donnée personnelle,
// et StoreKit le revaliderait de toute façon.

@MainActor
enum DataEraser {

    struct Options {
        /// Supprime aussi les échantillons d'eau écrits par AquApp dans Santé.
        var includeHealthData = false
    }

    static func eraseAll(
        store: AppDataStore,
        xpManager: XPManager,
        achievementManager: AchievementManager,
        challengeManager: ChallengeManager,
        options: Options = Options(),
        defaults: UserDefaults = .standard,
        appDomain: String = Bundle.main.bundleIdentifier ?? KeychainManager.service,
        groupDefaults: UserDefaults? = UserDefaults(suiteName: WidgetBridge.appGroup),
        groupDomain: String = WidgetBridge.appGroup,
        // Effets système, remplaçables dans les tests (ils partagent le simulateur de l'app)
        removeNotifications: @MainActor () async -> Void = DataEraser.removeAllNotifications,
        removeProfilePhoto: @MainActor () -> Void = { ProfilePhotoManager.shared.remove() }
    ) async {
        // 1. Santé d'abord : l'autorisation d'écriture doit encore être connue.
        if options.includeHealthData {
            await HealthKitWriter.shared.deleteAllWrittenByApp()
        }

        // 2. Base de données
        try? store.eraseAllEntries()

        // 3. Rappels et notifications d'AquApp
        await removeNotifications()

        // 4. Fichiers
        removeProfilePhoto()

        // 5. Trousseau (on garde uniquement le statut Premium)
        let wasPremium = PremiumManager.shared.isPremium
        KeychainManager.shared.deleteAll()
        PremiumManager.shared.set(wasPremium)

        // 6. Réglages. Clé par clé (et non removePersistentDomain) pour que les
        //    @AppStorage soient notifiés. `onboardingCompleted` part en dernier (étape 8).
        for key in keys(of: defaults, domain: appDomain) where key != onboardingKey {
            defaults.removeObject(forKey: key)
        }
        if let groupDefaults {
            for key in keys(of: groupDefaults, domain: groupDomain) {
                groupDefaults.removeObject(forKey: key)
            }
        }

        // 7. État en mémoire, comme au premier lancement
        HealthDataManager.shared.resetAfterErase()
        xpManager.reloadAfterErase()
        achievementManager.reloadAfterErase()
        challengeManager.reloadAfterErase()
        store.reloadAfterErase()

        // 8. Retour à l'onboarding
        defaults.removeObject(forKey: onboardingKey)
    }

    static let onboardingKey = "onboardingCompleted"

    static func removeAllNotifications() async {
        await ReminderScheduler.cancelAll()
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    private static func keys(of defaults: UserDefaults, domain: String) -> [String] {
        defaults.persistentDomain(forName: domain).map { Array($0.keys) } ?? []
    }
}
