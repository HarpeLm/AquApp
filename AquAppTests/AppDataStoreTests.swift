//
//  AppDataStoreTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 07/09/2026.
//


import XCTest
import SwiftData
@testable import AquApp

@MainActor
final class AppDataStoreTests: XCTestCase {

    var container: ModelContainer!
    var store: AppDataStore!

    override func setUp() async throws {
        try await super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
            configurations: config
        )
        // ⚠️ Adapte si ton init a une autre signature (ex: init(container:))
        store = AppDataStore(modelContext: container.mainContext)
    }

    override func tearDown() async throws {
        try? await Task.sleep(for: .seconds(1.0)) // laisse mourir les tasks background
        for key in ["dailyGoalMl", "isPremiumUser", "last_reset_date", "heatwave_days"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        store = nil
        container = nil
        try await super.tearDown()
    }

    func testAddWater_SumsToday() {
        store.addWater(amountMl: 250)
        store.addWater(amountMl: 250)
        XCTAssertEqual(store.todayWaterMl, 500, accuracy: 0.01)
    }

    func testGoalReached_Flag() {
        store.dailyGoalMl = 500
        store.addWater(amountMl: 499)
        XCTAssertFalse(store.todayGoalReached)
        store.addWater(amountMl: 1)
        XCTAssertTrue(store.todayGoalReached)
    }

    func testDeleteWater_Removes() {
        store.addWater(amountMl: 300)
        let entry = store.allWaterEntries().last!
        store.deleteWater(entry)
        XCTAssertEqual(store.todayWaterMl, 0, accuracy: 0.01)
        XCTAssertTrue(store.allWaterEntries().isEmpty)
    }

    func testAlcohol_CompensationReducesNetWater() {
        store.addWater(amountMl: 500)
        store.addAlcohol(amountMl: 500, type: .beer)
        XCTAssertEqual(store.todayWaterMl, 500 - 197.25, accuracy: 0.01)
    }

    func testCleanOldData_NonPremium_DeletesBeyond30Days() {
        let old = Calendar.current.date(byAdding: .day, value: -40, to: Date())!
        store.addWater(amountMl: 100, date: old)
        store.addWater(amountMl: 250)
        store.isPremiumUser = false
        store.cleanOldDataIfNeeded()
        let remaining = store.allWaterEntries()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.amountMl, 250)
    }

    func testCleanOldData_Premium_KeepsEverything() {
        let old = Calendar.current.date(byAdding: .day, value: -40, to: Date())!
        store.addWater(amountMl: 100, date: old)
        store.isPremiumUser = true
        store.cleanOldDataIfNeeded()
        XCTAssertEqual(store.allWaterEntries().count, 1)
    }

    func testPerformMidnightReset_SetsLastResetDate() {
        store.performMidnightReset()
        let saved = UserDefaults.standard.object(forKey: "last_reset_date") as? Date
        XCTAssertEqual(saved, Calendar.current.startOfDay(for: Date()))
    }
}
