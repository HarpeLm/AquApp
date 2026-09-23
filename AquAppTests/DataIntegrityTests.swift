//
//  DataIntegrityTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 13/09/2026.
//


import XCTest
import SwiftData
@testable import AquApp

@MainActor
final class DataIntegrityTests: XCTestCase {

    private var container: ModelContainer!
    private var store: AppDataStore!

    override func setUp() async throws {
        try await super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
            configurations: config
        )
        store = AppDataStore(modelContext: container.mainContext)

        HealthDataManager.shared.setTotalWaterMl(0)
        HealthDataManager.shared.setTotalAlcoholMl(0)
    }

    override func tearDown() async throws {
        store = nil
        container = nil
        try await super.tearDown()
    }

    func testAddWater_updatesTotalConsistently() throws {
        store.addWater(amountMl: 500)
        XCTAssertEqual(HealthDataManager.shared.totalWaterMl, 500,
            "Total Keychain doit refléter SwiftData")
    }

    func testAddWater_invalidValues_rejected() {
        let invalidValues: [Double] = [-100, 0, .infinity, .nan, 6000]
        for value in invalidValues {
            let before = HealthDataManager.shared.totalWaterMl
            store.addWater(amountMl: value)
            XCTAssertEqual(HealthDataManager.shared.totalWaterMl, before,
                "La valeur \(value) doit être rejetée sans modifier les totaux")
        }
    }

    func testAddAlcohol_invalidValues_rejected() {
        let invalidValues: [Double] = [-50, 0, .infinity, 10000]
        for value in invalidValues {
            let before = HealthDataManager.shared.totalAlcoholMl
            store.addAlcohol(amountMl: value, type: .beer)
            XCTAssertEqual(HealthDataManager.shared.totalAlcoholMl, before,
                "addAlcohol(\(value)) doit être rejeté")
        }
    }

    func testDeleteWater_decrementsTotal() throws {
        store.addWater(amountMl: 500)
        XCTAssertEqual(HealthDataManager.shared.totalWaterMl, 500)

        let entries = store.todayWaterEntries()
        XCTAssertEqual(entries.count, 1)

        store.deleteWater(entries[0])
        XCTAssertEqual(HealthDataManager.shared.totalWaterMl, 0,
            "La suppression doit décrémenter le total Keychain")
    }

    func testBootstrap_restoresTotalsIfEmpty() throws {
        let entry1 = WaterEntry(amountMl: 300, date: Date())
        let entry2 = WaterEntry(amountMl: 200, date: Date())
        container.mainContext.insert(entry1)
        container.mainContext.insert(entry2)
        try container.mainContext.save()

        HealthDataManager.shared.setTotalWaterMl(0)

        store.recalculateCumulativeTotals()

        XCTAssertEqual(HealthDataManager.shared.totalWaterMl, 500)
    }
}
