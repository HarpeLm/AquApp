//
//  HealthDataManager.swift
//  AquApp
//
//  Created by Fabian Dargaud on 09/09/2026.
//

import Foundation
import Combine
import HealthKit
import SwiftUI

@MainActor
final class HealthDataManager: ObservableObject {

    static let shared = HealthDataManager()
    private let km = KeychainManager.shared
    private let d  = UserDefaults.standard

    // MARK: - Profil

    @Published private(set) var weightKg:  Double
    @Published private(set) var heightCm:  Double
    @Published private(set) var gender:    String
    @Published private(set) var firstName: String

    // MARK: - Streaks & progression

    @Published private(set) var currentStreak:   Int
    @Published private(set) var totalGoalDays:   Int
    @Published private(set) var soberStreak:     Int
    @Published private(set) var xpTotal:         Int
    @Published private(set) var heatwaveDays:    Double
    @Published private(set) var soberDaysTotal:  Double
    @Published private(set) var totalWaterMl:    Double
    @Published private(set) var totalAlcoholMl:  Double

    // MARK: - Date d'installation

    @Published private(set) var firstLaunchDate: Date

    /// Jour d'alcool le plus récent parmi les entrées supprimées par le nettoyage non-Premium.
    private(set) var prunedAlcoholDate: Date?

    // MARK: - Progrès succès/défis (dict JSON en Keychain)

    @Published private(set) var achievementProgress:  [String: Double]
    @Published private(set) var achievementCompleted: [String: Bool]
    @Published private(set) var challengeCompleted:   [String: Bool]

    private init() {
        self.weightKg  = km.getDouble(forKey: "userWeightKg")
                        ?? (d.double(forKey: "userWeightKg") != 0 ? d.double(forKey: "userWeightKg") : 70)
        self.heightCm  = km.getDouble(forKey: "userHeightCm")
                        ?? (d.double(forKey: "userHeightCm") != 0 ? d.double(forKey: "userHeightCm") : 170)
        self.gender    = km.getString(forKey: "userGender")
                        ?? d.string(forKey: "userGender") ?? "notSpecified"
        self.firstName = km.getString(forKey: "userFirstName")
                        ?? d.string(forKey: "userFirstName") ?? ""

        self.currentStreak  = km.getDouble(forKey: "current_streak").map { Int($0) }
                              ?? d.integer(forKey: "current_streak")
        self.totalGoalDays  = km.getDouble(forKey: "total_goal_days").map { Int($0) }
                              ?? d.integer(forKey: "total_goal_days")
        self.soberStreak    = km.getDouble(forKey: "sober_streak").map { Int($0) }
                              ?? d.integer(forKey: "sober_streak")
        self.xpTotal        = km.getDouble(forKey: "xp_total").map { Int($0) }
                              ?? d.integer(forKey: "xp_total")
        self.heatwaveDays   = km.getDouble(forKey: "heatwave_days")
                              ?? d.double(forKey: "heatwave_days")
        self.soberDaysTotal = km.getDouble(forKey: "sober_days_total")
                              ?? d.double(forKey: "sober_days_total")
        self.totalWaterMl   = km.getDouble(forKey: "total_water_ml")
                              ?? d.double(forKey: "total_water_ml")
        self.totalAlcoholMl = km.getDouble(forKey: "total_alcohol_ml")
                              ?? d.double(forKey: "total_alcohol_ml")

        if let keychainDate = km.getString(forKey: "aquapp_first_launch_date"),
           let ti = Double(keychainDate) {
            self.firstLaunchDate = Date(timeIntervalSince1970: ti)
        } else if let savedDate = d.object(forKey: "aquapp_first_launch_date") as? Date {
            self.firstLaunchDate = savedDate
        } else {
            self.firstLaunchDate = Date()
        }

        self.prunedAlcoholDate = km.getDouble(forKey: "pruned_alcohol_date").map { Date(timeIntervalSince1970: $0) }

        self.achievementProgress  = Self.loadJSON(key: "ach_progress_dict", km: km) ?? [:]
        self.achievementCompleted = Self.loadJSON(key: "ach_completed_dict", km: km) ?? [:]
        self.challengeCompleted   = Self.loadJSON(key: "completed_dict",     km: km) ?? [:]

        migrateIfNeeded()
    }

    // MARK: - Setters profil
    // Chaque écriture dans le Trousseau coûte (suppression + ajout) : on n'écrit que
    // si la valeur change. Ajouter de l'eau rappelle ces setters des dizaines de fois.

    func setWeight(_ v: Double)    { guard v != weightKg  else { return }; km.set(v, forKey: "userWeightKg");  weightKg = v }
    func setHeight(_ v: Double)    { guard v != heightCm  else { return }; km.set(v, forKey: "userHeightCm");  heightCm = v }
    func setGender(_ v: String)    { guard v != gender    else { return }; km.set(v, forKey: "userGender");    gender = v }
    func setFirstName(_ v: String) { guard v != firstName else { return }; km.set(v, forKey: "userFirstName"); firstName = v }

    // MARK: - Setters streaks/progression

    func setCurrentStreak(_ v: Int)     { guard v != currentStreak  else { return }; km.set(Double(v), forKey: "current_streak");  currentStreak = v }
    func setTotalGoalDays(_ v: Int)     { guard v != totalGoalDays  else { return }; km.set(Double(v), forKey: "total_goal_days"); totalGoalDays = v }
    func setSoberStreak(_ v: Int)       { guard v != soberStreak    else { return }; km.set(Double(v), forKey: "sober_streak");    soberStreak = v }
    func setXPTotal(_ v: Int)           { guard v != xpTotal        else { return }; km.set(Double(v), forKey: "xp_total");        xpTotal = v }
    func setHeatwaveDays(_ v: Double)   { guard v != heatwaveDays   else { return }; km.set(v, forKey: "heatwave_days");           heatwaveDays = v }
    func setSoberDaysTotal(_ v: Double) { guard v != soberDaysTotal else { return }; km.set(v, forKey: "sober_days_total");        soberDaysTotal = v }
    func setFirstLaunchDate(_ v: Date) {
        km.set(String(v.timeIntervalSince1970), forKey: "aquapp_first_launch_date")
        firstLaunchDate = v
    }
    func setPrunedAlcoholDate(_ v: Date) {
        guard v != prunedAlcoholDate else { return }
        km.set(v.timeIntervalSince1970, forKey: "pruned_alcohol_date")
        prunedAlcoholDate = v
    }

    // MARK: - Setters totaux cumulatifs (O(1))

    func setTotalWaterMl(_ v: Double)   { guard v != totalWaterMl   else { return }; km.set(v, forKey: "total_water_ml");   totalWaterMl = v }
    func setTotalAlcoholMl(_ v: Double) { guard v != totalAlcoholMl else { return }; km.set(v, forKey: "total_alcohol_ml"); totalAlcoholMl = v }
    func addWaterMl(_ delta: Double)    { setTotalWaterMl(totalWaterMl + delta) }
    func addAlcoholMl(_ delta: Double)  { setTotalAlcoholMl(totalAlcoholMl + delta) }

    // MARK: - Progrès succès/défis

    func setAchievementProgress(_ id: String, value: Double) {
        setAchievementStates(progress: [id: value], completed: [:])
    }

    func setAchievementCompleted(_ id: String, value: Bool) {
        setAchievementStates(progress: [:], completed: [id: value])
    }

    /// Enregistre l'état de plusieurs succès en une fois : chaque dictionnaire est écrit
    /// au plus une fois, et seulement s'il a changé.
    func setAchievementStates(progress: [String: Double], completed: [String: Bool]) {
        let newProgress  = achievementProgress.merging(progress) { _, new in new }
        let newCompleted = achievementCompleted.merging(completed) { _, new in new }
        if newProgress != achievementProgress {
            achievementProgress = newProgress
            saveJSON(dict: newProgress, key: "ach_progress_dict")
        }
        if newCompleted != achievementCompleted {
            achievementCompleted = newCompleted
            saveJSON(dict: newCompleted, key: "ach_completed_dict")
        }
    }

    func setChallengeCompleted(_ id: String, value: Bool) {
        guard challengeCompleted[id] != value else { return }
        challengeCompleted[id] = value
        saveJSON(dict: challengeCompleted, key: "completed_dict")
    }

    // MARK: - Pas du jour (HealthKit, repli sur le dernier cache)

    func fetchTodaySteps(completion: @escaping (Double) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(d.double(forKey: "cached_steps_today"))
            return
        }
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let store = HKHealthStore()
        let startDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startDay, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
            UserDefaults.standard.set(steps, forKey: "cached_steps_today")
            DispatchQueue.main.async { completion(steps) }
        }
        store.execute(query)
    }

    func achievementProgressValue(_ id: String) -> Double { achievementProgress[id] ?? 0 }
    func isAchievementCompleted(_ id: String) -> Bool { achievementCompleted[id] ?? false }
    func isChallengeCompleted(_ id: String) -> Bool { challengeCompleted[id] ?? false }

    // MARK: - Bindings SwiftUI

    var weightBinding:    Binding<Double> { Binding(get: { self.weightKg },  set: { self.setWeight($0) }) }
    var heightBinding:    Binding<Double> { Binding(get: { self.heightCm },  set: { self.setHeight($0) }) }
    var genderBinding:    Binding<String> { Binding(get: { self.gender },    set: { self.setGender($0) }) }
    var firstNameBinding: Binding<String> { Binding(get: { self.firstName }, set: { self.setFirstName($0) }) }

    // MARK: - Migration UserDefaults → Keychain

    private func migrateIfNeeded() {
        // Valeurs lues dans l'ancien UserDefaults (init) : on les recopie dans le Trousseau
        // AVANT d'effacer la copie plist. Les setters n'écrivent plus une valeur inchangée,
        // donc sans cette copie elles seraient perdues au lancement suivant.
        let legacy: [(String, () -> Void)] = [
            ("userWeightKg",     { self.km.set(self.weightKg, forKey: "userWeightKg") }),
            ("userHeightCm",     { self.km.set(self.heightCm, forKey: "userHeightCm") }),
            ("userGender",       { self.km.set(self.gender, forKey: "userGender") }),
            ("userFirstName",    { self.km.set(self.firstName, forKey: "userFirstName") }),
            ("current_streak",   { self.km.set(Double(self.currentStreak), forKey: "current_streak") }),
            ("total_goal_days",  { self.km.set(Double(self.totalGoalDays), forKey: "total_goal_days") }),
            ("sober_streak",     { self.km.set(Double(self.soberStreak), forKey: "sober_streak") }),
            ("xp_total",         { self.km.set(Double(self.xpTotal), forKey: "xp_total") }),
            ("heatwave_days",    { self.km.set(self.heatwaveDays, forKey: "heatwave_days") }),
            ("sober_days_total", { self.km.set(self.soberDaysTotal, forKey: "sober_days_total") }),
            ("aquapp_first_launch_date", {
                self.km.set(String(self.firstLaunchDate.timeIntervalSince1970), forKey: "aquapp_first_launch_date")
            }),
            ("total_water_ml",   { self.km.set(self.totalWaterMl, forKey: "total_water_ml") }),
            ("total_alcohol_ml", { self.km.set(self.totalAlcoholMl, forKey: "total_alcohol_ml") }),
        ]
        for (key, copyToKeychain) in legacy where d.object(forKey: key) != nil {
            copyToKeychain()
            d.removeObject(forKey: key)
        }

        var achProg = achievementProgress
        var achComp = achievementCompleted
        var chaComp = challengeCompleted
        for key in d.dictionaryRepresentation().keys {
            if key.hasPrefix("ach_progress_") {
                achProg[String(key.dropFirst("ach_progress_".count))] = d.double(forKey: key)
                d.removeObject(forKey: key)
            } else if key.hasPrefix("ach_completed_") {
                achComp[String(key.dropFirst("ach_completed_".count))] = d.bool(forKey: key)
                d.removeObject(forKey: key)
            } else if key.hasPrefix("completed_") {
                chaComp[String(key.dropFirst("completed_".count))] = d.bool(forKey: key)
                d.removeObject(forKey: key)
            }
        }
        achievementProgress  = achProg
        achievementCompleted = achComp
        challengeCompleted   = chaComp
        saveJSON(dict: achProg, key: "ach_progress_dict")
        saveJSON(dict: achComp, key: "ach_completed_dict")
        saveJSON(dict: chaComp, key: "completed_dict")
    }

    // MARK: - JSON helpers

    private static func loadJSON<T: Decodable>(key: String, km: KeychainManager) -> T? {
        guard let s = km.getString(forKey: key), let data = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func saveJSON<T: Encodable>(dict: T, key: String) {
        guard let data = try? JSONEncoder().encode(dict),
              let s = String(data: data, encoding: .utf8) else { return }
        km.set(s, forKey: key)
    }

    // MARK: - Effacement des données

    /// Après `KeychainManager.deleteAll()` : remet l'état en mémoire à celui d'un premier
    /// lancement, sans réécrire de valeurs dans le Trousseau (sauf la date d'installation).
    func resetAfterErase() {
        weightKg = 70; heightCm = 170; gender = "notSpecified"; firstName = ""
        currentStreak = 0; totalGoalDays = 0; soberStreak = 0; xpTotal = 0
        heatwaveDays = 0; soberDaysTotal = 0
        totalWaterMl = 0; totalAlcoholMl = 0
        prunedAlcoholDate = nil
        achievementProgress = [:]; achievementCompleted = [:]; challengeCompleted = [:]
        setFirstLaunchDate(Date())
    }

    // MARK: - Tests

    func resetForTests() {
        // Écrit même si la mémoire contient déjà ces valeurs (les setters les ignoreraient)
        km.set(70.0, forKey: "userWeightKg");          weightKg = 70
        km.set(170.0, forKey: "userHeightCm");         heightCm = 170
        km.set("notSpecified", forKey: "userGender");  gender = "notSpecified"
        km.set("", forKey: "userFirstName");           firstName = ""
        for key in ["current_streak", "total_goal_days", "sober_streak", "xp_total",
                    "heatwave_days", "sober_days_total", "total_water_ml", "total_alcohol_ml"] {
            km.set(0.0, forKey: key)
        }
        currentStreak = 0; totalGoalDays = 0; soberStreak = 0; xpTotal = 0
        heatwaveDays = 0; soberDaysTotal = 0; totalWaterMl = 0; totalAlcoholMl = 0
        km.delete(forKey: "pruned_alcohol_date"); prunedAlcoholDate = nil
        achievementProgress = [:]; achievementCompleted = [:]; challengeCompleted = [:]
        saveJSON(dict: achievementProgress, key: "ach_progress_dict")
        saveJSON(dict: achievementCompleted, key: "ach_completed_dict")
        saveJSON(dict: challengeCompleted, key: "completed_dict")
    }
}
