//
//  HealthDataManager.swift
//  AquApp
//
//  Created by Fabian Dargaud on 09/09/2026.
//

import Foundation
import Combine
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

        self.achievementProgress  = Self.loadJSON(key: "ach_progress_dict", km: km) ?? [:]
        self.achievementCompleted = Self.loadJSON(key: "ach_completed_dict", km: km) ?? [:]
        self.challengeCompleted   = Self.loadJSON(key: "completed_dict",     km: km) ?? [:]

        migrateIfNeeded()
    }

    // MARK: - Setters profil

    func setWeight(_ v: Double)    { km.set(v, forKey: "userWeightKg");  weightKg = v }
    func setHeight(_ v: Double)    { km.set(v, forKey: "userHeightCm");  heightCm = v }
    func setGender(_ v: String)    { km.set(v, forKey: "userGender");    gender = v }
    func setFirstName(_ v: String) { km.set(v, forKey: "userFirstName"); firstName = v }

    // MARK: - Setters streaks/progression

    func setCurrentStreak(_ v: Int)     { km.set(Double(v), forKey: "current_streak");  currentStreak = v }
    func setTotalGoalDays(_ v: Int)     { km.set(Double(v), forKey: "total_goal_days"); totalGoalDays = v }
    func setSoberStreak(_ v: Int)       { km.set(Double(v), forKey: "sober_streak");    soberStreak = v }
    func setXPTotal(_ v: Int)           { km.set(Double(v), forKey: "xp_total");        xpTotal = v }
    func setHeatwaveDays(_ v: Double)   { km.set(v, forKey: "heatwave_days");           heatwaveDays = v }
    func setSoberDaysTotal(_ v: Double) { km.set(v, forKey: "sober_days_total");        soberDaysTotal = v }
    func setFirstLaunchDate(_ v: Date) {
        km.set(String(v.timeIntervalSince1970), forKey: "aquapp_first_launch_date")
        firstLaunchDate = v
    }

    // MARK: - Setters totaux cumulatifs (O(1))

    func setTotalWaterMl(_ v: Double)   { km.set(v, forKey: "total_water_ml");   totalWaterMl = v }
    func setTotalAlcoholMl(_ v: Double) { km.set(v, forKey: "total_alcohol_ml"); totalAlcoholMl = v }
    func addWaterMl(_ delta: Double)    { setTotalWaterMl(totalWaterMl + delta) }
    func addAlcoholMl(_ delta: Double)  { setTotalAlcoholMl(totalAlcoholMl + delta) }

    // MARK: - Progrès succès/défis

    func setAchievementProgress(_ id: String, value: Double) {
        achievementProgress[id] = value
        saveJSON(dict: achievementProgress, key: "ach_progress_dict")
    }

    func setAchievementCompleted(_ id: String, value: Bool) {
        achievementCompleted[id] = value
        saveJSON(dict: achievementCompleted, key: "ach_completed_dict")
    }

    func setChallengeCompleted(_ id: String, value: Bool) {
        challengeCompleted[id] = value
        saveJSON(dict: challengeCompleted, key: "completed_dict")
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
        for key in ["userWeightKg", "userHeightCm", "userGender", "userFirstName",
                    "current_streak", "total_goal_days", "sober_streak", "xp_total",
                    "heatwave_days", "sober_days_total", "aquapp_first_launch_date",
                    "total_water_ml", "total_alcohol_ml"]
            where d.object(forKey: key) != nil { d.removeObject(forKey: key) }

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

    // MARK: - Tests

    func resetForTests() {
        setWeight(70); setHeight(170); setGender("notSpecified"); setFirstName("")
        setCurrentStreak(0); setTotalGoalDays(0); setSoberStreak(0); setXPTotal(0)
        setHeatwaveDays(0); setSoberDaysTotal(0)
        setTotalWaterMl(0); setTotalAlcoholMl(0)
        achievementProgress = [:]; achievementCompleted = [:]; challengeCompleted = [:]
    }
}
