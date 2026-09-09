//
//  AppDataStoreRulesTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 08/09/2026.
//


import XCTest
import SwiftData
@testable import AquApp

@MainActor
final class AppDataStoreRulesTests: XCTestCase {

    var container: ModelContainer!
    var store: AppDataStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try ModelContainer(
            for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = AppDataStore(modelContext: container.mainContext)
    }

    override func tearDown() async throws {
        try? await Task.sleep(for: .seconds(0.5))
        for key in ["dailyGoalMl", "isPremiumUser", "last_reset_date", "heatwave_days",
                    "current_streak", "total_goal_days", "sober_streak",
                    "cached_steps_today", "aquapp_first_launch_date"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        store = nil; container = nil
        try await super.tearDown()
    }

    // MARK: - Garde-fous addWater / addAlcohol

    func testAddWater_RejectsInvalidValues() {
        for bad in [0.0, -0.001, -100, .nan, .infinity, -.infinity, 5000.0001, 100_000] {
            store.addWater(amountMl: bad)
        }
        XCTAssertTrue(store.allWaterEntries().isEmpty, "Aucune valeur aberrante ne doit entrer en base")
    }

    func testAddWater_AcceptsBoundaryValues() {
        store.addWater(amountMl: 0.001)
        store.addWater(amountMl: 5000)   // borne haute inclusive
        XCTAssertEqual(store.allWaterEntries().count, 2)
    }

    func testAddAlcohol_RejectsInvalidValues() {
        for bad in [0.0, -50, .nan, .infinity, 5000.0001] {
            store.addAlcohol(amountMl: bad, type: .beer)
        }
        XCTAssertTrue(store.allAlcoholEntries().isEmpty)
    }

    // MARK: - Objectif effectif & progress

    func testEffectiveGoal_HeatwavePriority() {
        store.dailyGoalMl = 2000
        XCTAssertEqual(store.effectiveGoalMl, 2000)
        store.heatwaveGoalMl = 3000
        XCTAssertEqual(store.effectiveGoalMl, 3000)
        store.heatwaveGoalMl = nil
        XCTAssertEqual(store.effectiveGoalMl, 2000)
    }

    func testTodayProgress_ClampedTo1() {
        store.dailyGoalMl = 100
        store.addWater(amountMl: 500)
        XCTAssertEqual(store.todayProgress, 1.0, accuracy: 0.0001)
    }

    func testTodayWaterMl_NeverNegative() {
        store.addWater(amountMl: 100)
        store.addAlcohol(amountMl: 1000, type: .spirits) // compense ~315 ml
        XCTAssertEqual(store.todayWaterMl, 0, accuracy: 0.01)
    }

    // MARK: - Streaks

    func testGoalStreak_FirstDay() {
        store.dailyGoalMl = 500
        store.addWater(amountMl: 500)
        XCTAssertEqual(store.currentStreak, 1)
        XCTAssertEqual(store.totalGoalDays, 1)
    }

    func testSoberStreak_ResetsOnAlcohol() {
        store.addAlcohol(amountMl: 250, type: .beer)
        XCTAssertEqual(store.soberDaysStreak, 0)
    }

    // MARK: - Stats & graphique

    func testLast7DaysWater_AlwaysSevenSlots() {
        XCTAssertEqual(store.last7DaysWater.count, 7)
    }

    func testLast7DaysWater_TodayIsNetOfAlcohol() {
        store.addWater(amountMl: 400)
        store.addAlcohol(amountMl: 500, type: .beer)   // -197.25
        XCTAssertEqual(store.last7DaysWater.last!.ml, 400 - 197.25, accuracy: 0.01)
    }

    func testContributionRatios_TodayAlwaysPresent() {
        store.addWater(amountMl: 250)
        let today = Calendar.current.startOfDay(for: Date())
        XCTAssertNotNil(store.contributionRatios(days: 365)[today])
    }

    func testWeekTotalMl_SubtractsCompensation() {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        store.addWater(amountMl: 500)
        store.addAlcohol(amountMl: 500, type: .beer)
        XCTAssertEqual(store.weekTotalMl(from: start, to: end), 500 - 197.25, accuracy: 0.01)
    }

    func testAvgMlPerDay_ZeroWhenEmpty() {
        XCTAssertEqual(store.avgMlPerDay, 0)
    }

    // MARK: - Clean 30 jours : borne exacte

    func testCleanOldData_Boundary30Days() {
        let now       = Date()
        let tooOld    = now.addingTimeInterval(-31 * 86400)  // > 30 jours → purgée
        let stillKept = now.addingTimeInterval(-29 * 86400)  // < 30 jours → gardée
        store.addWater(amountMl: 222, date: tooOld)
        store.addWater(amountMl: 111, date: stillKept)
        store.isPremiumUser = false
        store.cleanOldDataIfNeeded()
        let remaining = store.allWaterEntries()
        XCTAssertEqual(remaining.count, 1, "seule l'entrée de moins de 30 jours doit survivre")
        XCTAssertEqual(remaining.first?.amountMl, 111)
    }
}
