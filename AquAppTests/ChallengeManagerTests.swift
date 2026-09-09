//
//  ChallengeManagerTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 08/09/2026.
//


import XCTest
import SwiftUI
@testable import AquApp

@MainActor
final class ChallengeManagerTests: XCTestCase {

    var manager: ChallengeManager!
    var retained: [ChallengeManager] = []

    override func setUp() async throws {
        try await super.setUp()
        let d = UserDefaults.standard
        d.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("progress_") || $0.hasPrefix("today_completed_")
                    || $0.hasPrefix("completed_") || $0.hasPrefix("grand_ecart_")
                    || $0 == "challenges_last_reset" || $0 == "isPremiumUser" }
            .forEach { d.removeObject(forKey: $0) }

        retained = []
        manager = ChallengeManager()
        retained.append(manager)
    }

    override func tearDown() async throws {
        try? await Task.sleep(for: .seconds(0.3)) // draine les callbacks HealthKit
        retained = []
        manager = nil
        try await super.tearDown()
    }

    // MARK: - Catalogue

    func testChallengeCatalog_Count() {
        XCTAssertEqual(manager.challenges.count, 10)
    }

    func testChallengeCatalog_Targets() {
        let expected: [(String, Double)] = [
            ("matinal", 1), ("grand_buveur", 3000), ("matin_champion", 1),
            ("cadence_parfaite", 6), ("grand_ecart", 2), ("flash_hydrate", 500),
            ("regulier", 4), ("soiree_tranquille", 1),
            ("active_day", 10000), ("recuperation", 300),
        ]
        for (id, target) in expected {
            XCTAssertEqual(manager.ch(id: id).targetProgress, target, id)
        }
    }

    // MARK: - Matinal

    func testMatinal_AnyWaterBefore9AM() {
        let early = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        manager.onWaterUpdated(totalTodayMl: 50, dailyGoalMl: 2000, dailyGoalReached: false,
                               drinkCount: 1, mlBeforeNine: 50,
                               waterEntries: [WaterEntry(amountMl: 50, date: early)], alcoholCount: 0)
        XCTAssertEqual(manager.ch(id: "matinal").status, .completed)
    }

    func testMatinal_NoWaterBefore9AM_NotCompleted() {
        let late = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        manager.onWaterUpdated(totalTodayMl: 500, dailyGoalMl: 2000, dailyGoalReached: false,
                               drinkCount: 1, mlBeforeNine: 0,
                               waterEntries: [WaterEntry(amountMl: 500, date: late)], alcoholCount: 0)
        XCTAssertNotEqual(manager.ch(id: "matinal").status, .completed)
    }

    // MARK: - Grand Buveur

    func testGrandBuveur_3000ml() {
        manager.onWaterUpdated(totalTodayMl: 2999, dailyGoalMl: 2000, dailyGoalReached: false,
                               drinkCount: 5, mlBeforeNine: 0, waterEntries: [], alcoholCount: 0)
        XCTAssertNotEqual(manager.ch(id: "grand_buveur").status, .completed)
        manager.onWaterUpdated(totalTodayMl: 3000, dailyGoalMl: 2000, dailyGoalReached: false,
                               drinkCount: 5, mlBeforeNine: 0, waterEntries: [], alcoholCount: 0)
        XCTAssertEqual(manager.ch(id: "grand_buveur").status, .completed)
    }

    // MARK: - Régulier

    func testRegulier_4Drinks() {
        manager.onWaterUpdated(totalTodayMl: 1000, dailyGoalMl: 2000, dailyGoalReached: false,
                               drinkCount: 3, mlBeforeNine: 0, waterEntries: [], alcoholCount: 0)
        XCTAssertNotEqual(manager.ch(id: "regulier").status, .completed)
        manager.onWaterUpdated(totalTodayMl: 1000, dailyGoalMl: 2000, dailyGoalReached: false,
                               drinkCount: 4, mlBeforeNine: 0, waterEntries: [], alcoholCount: 0)
        XCTAssertEqual(manager.ch(id: "regulier").status, .completed)
    }

    // MARK: - Matin de Champion

    func testMatinChampion_50PercentBeforeNoon() {
        let beforeNoon = Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date())!
        let entries = [WaterEntry(amountMl: 1000, date: beforeNoon)]
        manager.onWaterUpdated(totalTodayMl: 1000, dailyGoalMl: 2000, dailyGoalReached: false,
                               drinkCount: 1, mlBeforeNine: 1000, waterEntries: entries, alcoholCount: 0)
        XCTAssertEqual(manager.ch(id: "matin_champion").status, .completed)
    }

    func testMatinChampion_Below50Percent() {
        let beforeNoon = Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date())!
        let entries = [WaterEntry(amountMl: 999, date: beforeNoon)]
        manager.onWaterUpdated(totalTodayMl: 999, dailyGoalMl: 2000, dailyGoalReached: false,
                               drinkCount: 1, mlBeforeNine: 999, waterEntries: entries, alcoholCount: 0)
        XCTAssertNotEqual(manager.ch(id: "matin_champion").status, .completed)
    }

    // MARK: - Cadence Parfaite

    func testCadenceParfaite_All6WindowsCovered() {
        let cal = Calendar.current
        var entries: [WaterEntry] = []
        for h in [8, 10, 12, 14, 16, 18] {
            entries.append(WaterEntry(amountMl: 200, date: cal.date(bySettingHour: h, minute: 30, second: 0, of: Date())!))
        }
        manager.onWaterUpdated(totalTodayMl: 1200, dailyGoalMl: 2000, dailyGoalReached: false,
                               drinkCount: 6, mlBeforeNine: 0, waterEntries: entries, alcoholCount: 0)
        XCTAssertEqual(manager.ch(id: "cadence_parfaite").status, .completed)
    }

    func testCadenceParfaite_MissingOneWindow() {
        let cal = Calendar.current
        var entries: [WaterEntry] = []
        for h in [8, 10, 12, 14, 16] { // fenêtre 18-20 manquante
            entries.append(WaterEntry(amountMl: 200, date: cal.date(bySettingHour: h, minute: 30, second: 0, of: Date())!))
        }
        manager.onWaterUpdated(totalTodayMl: 1000, dailyGoalMl: 2000, dailyGoalReached: false,
                               drinkCount: 5, mlBeforeNine: 0, waterEntries: entries, alcoholCount: 0)
        XCTAssertNotEqual(manager.ch(id: "cadence_parfaite").status, .completed)
        XCTAssertEqual(manager.ch(id: "cadence_parfaite").currentProgress, 5)
    }

    // MARK: - Grand Écart

    func testGrandEcart_BothConditionsRequired() {
        let cal = Calendar.current
        let early = cal.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let late  = cal.date(bySettingHour: 21, minute: 30, second: 0, of: Date())!

        manager.onWaterUpdated(totalTodayMl: 100, dailyGoalMl: 2000, dailyGoalReached: false,
                               drinkCount: 1, mlBeforeNine: 100,
                               waterEntries: [WaterEntry(amountMl: 100, date: early)], alcoholCount: 0)
        XCTAssertNotEqual(manager.ch(id: "grand_ecart").status, .completed)

        manager.onWaterUpdated(totalTodayMl: 200, dailyGoalMl: 2000, dailyGoalReached: false,
                               drinkCount: 2, mlBeforeNine: 100,
                               waterEntries: [WaterEntry(amountMl: 100, date: early),
                                              WaterEntry(amountMl: 100, date: late)], alcoholCount: 0)
        XCTAssertEqual(manager.ch(id: "grand_ecart").status, .completed)
    }

    // MARK: - Flash Hydraté

    func testFlashHydrate_500mlIn30Minutes() {
        let t1 = Date()
        let entries = [WaterEntry(amountMl: 250, date: t1),
                       WaterEntry(amountMl: 250, date: t1.addingTimeInterval(20 * 60))]
        manager.onWaterUpdated(totalTodayMl: 500, dailyGoalMl: 2000, dailyGoalReached: false,
                               drinkCount: 2, mlBeforeNine: 0, waterEntries: entries, alcoholCount: 0)
        XCTAssertEqual(manager.ch(id: "flash_hydrate").status, .completed)
    }

    func testFlashHydrate_SingleBigDrink() {
        let entries = [WaterEntry(amountMl: 500, date: Date())]
        manager.onWaterUpdated(totalTodayMl: 500, dailyGoalMl: 2000, dailyGoalReached: false,
                               drinkCount: 1, mlBeforeNine: 0, waterEntries: entries, alcoholCount: 0)
        XCTAssertEqual(manager.ch(id: "flash_hydrate").status, .completed)
    }

    func testFlashHydrate_TooSpreadOut() {
        let t1 = Date()
        let entries = [WaterEntry(amountMl: 250, date: t1),
                       WaterEntry(amountMl: 250, date: t1.addingTimeInterval(40 * 60))]
        manager.onWaterUpdated(totalTodayMl: 500, dailyGoalMl: 2000, dailyGoalReached: false,
                               drinkCount: 2, mlBeforeNine: 0, waterEntries: entries, alcoholCount: 0)
        XCTAssertNotEqual(manager.ch(id: "flash_hydrate").status, .completed)
        XCTAssertEqual(manager.ch(id: "flash_hydrate").currentProgress, 250)
    }

    // MARK: - Soirée Tranquille

    func testSoireeTranquille_GoalAndNoAlcohol() {
        manager.onWaterUpdated(totalTodayMl: 2000, dailyGoalMl: 2000, dailyGoalReached: true,
                               drinkCount: 5, mlBeforeNine: 0, waterEntries: [], alcoholCount: 0)
        XCTAssertEqual(manager.ch(id: "soiree_tranquille").status, .completed)
    }

    func testSoireeTranquille_NotCompletedIfAlcoholPresent() {
        manager.onWaterUpdated(totalTodayMl: 2000, dailyGoalMl: 2000, dailyGoalReached: true,
                               drinkCount: 5, mlBeforeNine: 0, waterEntries: [], alcoholCount: 1)
        XCTAssertNotEqual(manager.ch(id: "soiree_tranquille").status, .completed)
    }

    func testSoireeTranquille_LostWhenAlcoholAdded() {
        manager.onWaterUpdated(totalTodayMl: 2000, dailyGoalMl: 2000, dailyGoalReached: true,
                               drinkCount: 5, mlBeforeNine: 0, waterEntries: [], alcoholCount: 0)
        XCTAssertEqual(manager.ch(id: "soiree_tranquille").status, .completed)
        manager.onAlcoholUpdated(alcoholCount: 1, dailyGoalReached: true)
        XCTAssertNotEqual(manager.ch(id: "soiree_tranquille").status, .completed)
    }

    // MARK: - Reset quotidien

    func testPerformDailyReset_ResetsProgress() {
        manager.onWaterUpdated(totalTodayMl: 3000, dailyGoalMl: 2000, dailyGoalReached: true,
                               drinkCount: 5, mlBeforeNine: 0, waterEntries: [], alcoholCount: 0)
        // Simule le passage au jour suivant (garde d'idempotence)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        UserDefaults.standard.set(yesterday, forKey: "challenges_last_reset")

        manager.performDailyReset()
        for c in manager.challenges {
            guard c.status != .locked else { continue }
            XCTAssertEqual(c.currentProgress, 0, "\(c.id) reset")
            XCTAssertNotEqual(c.status, .completed, "\(c.id) non-complété après reset")
        }
    }

    func testPerformDailyReset_OnlyOncePerDay() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        UserDefaults.standard.set(yesterday, forKey: "challenges_last_reset")
        manager.performDailyReset()
        let stamp = UserDefaults.standard.object(forKey: "challenges_last_reset") as? Date
        manager.performDailyReset() // même jour → no-op
        XCTAssertEqual(UserDefaults.standard.object(forKey: "challenges_last_reset") as? Date, stamp)
    }

    // MARK: - Progress ratio

    func testChallengeProgressRatio_ClampedTo1() {
        var c = Challenge(id: "x", sfSymbol: "x", symbolColor: .blue,
                          title: "x", titleEmoji: "", description: "x",
                          category: .hydration, isPro: false, targetProgress: 100)
        c.currentProgress = 150
        XCTAssertEqual(c.progressRatio, 1.0)
    }
}

extension ChallengeManager {
    fileprivate func ch(id: String) -> Challenge {
        challenges.first { $0.id == id }!
    }
}
