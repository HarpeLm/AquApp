//
//  WrappedDataBuilderTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 08/09/2026.
//


import XCTest
import SwiftData
@testable import AquApp

@MainActor
final class WrappedDataBuilderTests: XCTestCase {

    var container: ModelContainer!
    var store: AppDataStore!
    var xpManager: XPManager!
    var achievementManager: AchievementManager!
    var challengeManager: ChallengeManager!
    var retained: [AnyObject] = []

    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.removeObject(forKey: "heatwave_days")
        container = try ModelContainer(
            for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = AppDataStore(modelContext: container.mainContext)
        xpManager = XPManager()
        achievementManager = AchievementManager()
        challengeManager = ChallengeManager()
        retained = [store, xpManager, achievementManager, challengeManager]
    }

    override func tearDown() async throws {
        try? await Task.sleep(for: .seconds(0.3))
        retained = []
        store = nil; xpManager = nil; achievementManager = nil; challengeManager = nil
        container = nil
        UserDefaults.standard.removeObject(forKey: "heatwave_days")
        try await super.tearDown()
    }

    private func build() -> WrappedData {
        WrappedDataBuilder.build(
            store: store, xpManager: xpManager, achievementManager: achievementManager,
            challengeManager: challengeManager, modelContext: container.mainContext
        )
    }

    // MARK: - Cas vide

    func testEmptyYear_AllZeroes() {
        let w = build()
        XCTAssertEqual(w.totalLiters, 0)
        XCTAssertEqual(w.totalGlasses, 0)
        XCTAssertEqual(w.avgDailyMl, 0)
        XCTAssertEqual(w.goalDays, 0)
        XCTAssertEqual(w.bestStreak, 0)
        XCTAssertEqual(w.alcoholLiters, 0)
        XCTAssertEqual(w.monthlyTotals.count, 12)
        XCTAssertEqual(w.monthLabels.count, 12)
    }

    // MARK: - Total eau & verres

    func testTotalWater_GlassesCalculation() {
        let today = Date()
        store.addWater(amountMl: 250, date: today)
        store.addWater(amountMl: 250, date: today)
        store.addWater(amountMl: 250, date: today)
        store.addWater(amountMl: 125, date: today) // demi-verre non compté
        let w = build()
        XCTAssertEqual(w.totalLiters, 0.875, accuracy: 0.0001)
        XCTAssertEqual(w.totalGlasses, 3)
    }

    // MARK: - Moyenne journalière

    func testAvgDailyMl_ActiveDays() {
        let today = Calendar.current.startOfDay(for: Date())
        store.addWater(amountMl: 1000, date: today)
        store.addWater(amountMl: 2000, date: today.addingTimeInterval(-86400))
        XCTAssertEqual(build().avgDailyMl, 1500, accuracy: 0.01)
    }

    // MARK: - Meilleur mois (reste dans le mois courant)

    func testBestMonth_IdentifiedCorrectly() {
        let cal = Calendar.current
        let nbDays = min(10, cal.component(.day, from: Date()))
        for day in 0..<nbDays {
            store.addWater(amountMl: 500, date: cal.date(byAdding: .day, value: -day, to: Date())!)
        }
        XCTAssertEqual(build().bestMonthLiters, Double(nbDays) * 0.5, accuracy: 0.01)
    }

    // MARK: - Objectifs atteints

    func testGoalDays_CountsReachedRecords() {
        let today = Calendar.current.startOfDay(for: Date())
        let ctx = container.mainContext
        ctx.insert(DayRecord(date: today, goalMl: 2000, goalReached: true))
        ctx.insert(DayRecord(date: today.addingTimeInterval(-86400), goalMl: 2000, goalReached: true))
        try? ctx.save()
        XCTAssertEqual(build().goalDays, 2)
    }

    // MARK: - Meilleur streak

    func testBestStreak_ConsecutiveDays() {
        let today = Calendar.current.startOfDay(for: Date())
        let ctx = container.mainContext
        for i in 0..<5 {
            ctx.insert(DayRecord(date: today.addingTimeInterval(Double(-i) * 86400), goalMl: 2000, goalReached: true))
        }
        ctx.insert(DayRecord(date: today.addingTimeInterval(-6 * 86400), goalMl: 2000, goalReached: false))
        try? ctx.save()
        XCTAssertEqual(build().bestStreak, 5)
    }

    // MARK: - Jours sobres

    func testSoberDays_TotalMinusAlcoholDays() {
        store.addAlcohol(amountMl: 250, type: .beer)
        XCTAssertLessThanOrEqual(build().soberDays, 364)
    }

    // MARK: - Alcool

    func testAlcohol_TotalLiters() {
        store.addAlcohol(amountMl: 500, type: .beer)
        store.addAlcohol(amountMl: 500, type: .wine)
        XCTAssertEqual(build().alcoholLiters, 1.0, accuracy: 0.01)
    }

    // MARK: - Habitudes matinales

    func testMorningDays_CountsBefore9AM() {
        let cal = Calendar.current
        store.addWater(amountMl: 250, date: cal.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!)
        store.addWater(amountMl: 250, date: cal.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!)
        XCTAssertEqual(build().morningDays, 1)
    }

    // MARK: - Canicule

    func testHeatwaveDays_FromUserDefaults() {
        UserDefaults.standard.set(5.0, forKey: "heatwave_days")
        XCTAssertEqual(build().heatwaveDays, 5)
    }

    // MARK: - Monthly totals

    func testMonthlyTotals_Always12Values() {
        let w = build()
        XCTAssertEqual(w.monthlyTotals.count, 12)
        XCTAssertEqual(w.monthLabels.count, 12)
        XCTAssertEqual(w.monthlyTotals.reduce(0, +), 0, accuracy: 0.0001)
    }
}
