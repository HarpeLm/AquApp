#if DEBUG
import Foundation

/// Données fictives pour les captures d'écran (README, App Store). Lancer avec `-demoData`.
/// La base SwiftData est en mémoire, mais le Keychain et les réglages du simulateur sont
/// modifiés : à utiliser sur un simulateur dédié, jamais sur celui de développement.
@MainActor
enum DemoData {
    static var isActive: Bool { ProcessInfo.processInfo.arguments.contains("-demoData") }

    /// À appeler avant la création des managers.
    static func prepareSettings() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "onboardingCompleted")
        defaults.set(true, forKey: HealthAuthorization.offeredKey)
        defaults.set(2500.0, forKey: "dailyGoalMl")
        defaults.set(true, forKey: ReminderScheduler.enabledKey)
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("xp_") {
            defaults.removeObject(forKey: key)
        }

        let health = HealthDataManager.shared
        health.resetForTests()
        health.setFirstName("Camille")
        health.setWeight(68)
        health.setHeight(172)
        health.setGender("female")
        health.setFirstLaunchDate(Calendar.current.date(byAdding: .day, value: -45, to: Date())!)
    }

    /// À appeler une fois les managers câblés : tout passe par le vrai pipeline
    /// (séries, XP, succès, défis), comme si l'utilisateur avait saisi ces verres.
    static func seed(_ store: AppDataStore) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let fullDay: [Double] = [330, 250, 500, 330, 250, 500, 400, 250]   // 2,81 L
        let lightDay: [Double] = [250, 330, 250, 400]                       // 1,23 L
        let missedDays: Set<Int> = [13, 14, 21, 30]
        let beerDays: Set<Int> = [9, 23]

        for daysAgo in (1...40).reversed() {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let glasses = missedDays.contains(daysAgo) ? lightDay : fullDay
            for (index, ml) in glasses.enumerated() {
                store.addWater(amountMl: ml, date: day.addingTimeInterval(Double(8 + index * 2) * 3600))
            }
            if beerDays.contains(daysAgo) {
                store.addAlcohol(amountMl: 330, type: .beer, date: day.addingTimeInterval(19 * 3600))
            }
        }

        // Aujourd'hui : 1,66 L sur 2,5 L, répartis sur les heures écoulées.
        let now = Date()
        for (minutesAgo, ml) in [(360, 330.0), (270, 250.0), (180, 500.0), (90, 330.0), (20, 250.0)] {
            let date = max(today, now.addingTimeInterval(-Double(minutesAgo) * 60))
            store.addWater(amountMl: ml, date: date)
        }
    }
}
#endif
