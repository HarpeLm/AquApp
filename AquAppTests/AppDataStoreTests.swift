//
//  AppDataStoreTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 07/09/2026.
//


//
//  AppDataStoreCumulativeTests.swift
//  AquAppTests
//

import Testing
import SwiftData
@testable import AquApp

@MainActor
@Suite("Totaux cumulatifs")
struct CumulativeTotalsTests {

    // ⚠️ Stockés : le ModelContainer doit rester vivant pendant tout le test.
    let container: ModelContainer
    let store: AppDataStore

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let c = try ModelContainer(
            for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
            configurations: config
        )
        self.container = c
        self.store = AppDataStore(modelContext: c.mainContext)
    }

    // NOTE IMPORTANTE : assertions en DELTA, jamais en valeurs absolues.
    // HealthDataManager.shared est un singleton process-wide, également
    // modifié par les suites XCTest qui tournent EN PARALLÈLE dans le
    // même process. Entre deux lectures synchrones sur le main actor,
    // aucun autre code ne peut s'intercaler → les deltas sont sûrs.

    @Test func addWaterIncrementsTotal() {
        let before = HealthDataManager.shared.totalWaterMl
        store.addWater(amountMl: 500)
        #expect(HealthDataManager.shared.totalWaterMl == before + 500)
    }

    @Test func addAlcoholIncrementsTotal() {
        let before = HealthDataManager.shared.totalAlcoholMl
        store.addAlcohol(amountMl: 250, type: .beer)
        #expect(HealthDataManager.shared.totalAlcoholMl == before + 250)
    }

    @Test func deleteWaterDecrementsTotal() {
        let before = HealthDataManager.shared.totalWaterMl
        store.addWater(amountMl: 500)
        let entry = store.todayWaterEntries().first!   // la plus récente = 500 ml
        store.deleteWater(entry)
        #expect(HealthDataManager.shared.totalWaterMl == before)
    }

    @Test func totalLitersFollowsKeychainTotal() {
        let beforeWater = HealthDataManager.shared.totalWaterMl
        store.addWater(amountMl: 2500)
        #expect(store.totalWaterLiters == (beforeWater + 2500) / 1000.0)

        let beforeAlcohol = HealthDataManager.shared.totalAlcoholMl
        store.addAlcohol(amountMl: 500, type: .wine)
        #expect(store.totalAlcoholLiters == (beforeAlcohol + 500) / 1000.0)
    }
}
