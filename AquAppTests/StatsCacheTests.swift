import XCTest
import SwiftData
@testable import AquApp

@MainActor
final class StatsCacheTests: XCTestCase {

    private var container: ModelContainer!
    private var store: AppDataStore!
    private var originalFirstLaunchDate: Date!

    override func setUp() async throws {
        try await super.setUp()
        HealthDataManager.shared.resetForTests()
        // Simulateur neuf (CI) : l'installation daterait d'aujourd'hui et la série ignorerait « hier ».
        originalFirstLaunchDate = HealthDataManager.shared.firstLaunchDate
        HealthDataManager.shared.setFirstLaunchDate(daysAgo(30))
        container = try ModelContainer(
            for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = AppDataStore(modelContext: container.mainContext)
        store.dailyGoalMl = 2000
        store.heatwaveGoalMl = nil
    }

    override func tearDown() async throws {
        store = nil
        container = nil
        HealthDataManager.shared.setFirstLaunchDate(originalFirstLaunchDate)
        try await super.tearDown()
    }

    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date())!
    }

    // MARK: - Jours actifs

    func testActiveDays_countsDistinctDaysOnly() {
        XCTAssertEqual(store.activeDaysTotal, 0)
        store.addWater(amountMl: 250)
        store.addWater(amountMl: 250)
        XCTAssertEqual(store.activeDaysTotal, 1, "deux verres le même jour = un jour")
        store.addWater(amountMl: 250, date: daysAgo(3))
        XCTAssertEqual(store.activeDaysTotal, 2)
    }

    func testActiveDays_deleteOnlyCountsWhenDayBecomesEmpty() throws {
        store.addWater(amountMl: 250)
        store.addWater(amountMl: 300)
        store.addWater(amountMl: 250, date: daysAgo(2))
        XCTAssertEqual(store.activeDaysTotal, 2)

        store.deleteWater(try XCTUnwrap(store.todayWaterEntries().first))
        XCTAssertEqual(store.activeDaysTotal, 2, "il reste un verre aujourd'hui")

        store.deleteWater(try XCTUnwrap(store.todayWaterEntries().first))
        XCTAssertEqual(store.activeDaysTotal, 1, "aujourd'hui est maintenant vide")
    }

    func testActiveDays_followsNonPremiumCleanup() {
        store.addWater(amountMl: 250, date: daysAgo(40))
        store.addWater(amountMl: 250)
        XCTAssertEqual(store.activeDaysTotal, 2)

        store.isPremiumUser = false
        store.cleanOldDataIfNeeded()

        XCTAssertEqual(store.activeDaysTotal, 1)
    }

    func testActiveDays_seesEntriesWrittenOutsideTheStoreAfterResync() throws {
        _ = store.activeDaysTotal
        container.mainContext.insert(WaterEntry(amountMl: 250, date: daysAgo(5)))
        try container.mainContext.save()

        store.recalculateGoalStreak()

        XCTAssertEqual(store.activeDaysTotal, 1)
    }

    // MARK: - Changement d'objectif

    func testSetDailyGoal_updatesTodayRecordStreakAndGrid() throws {
        container.mainContext.insert(DayRecord(date: Calendar.current.startOfDay(for: daysAgo(1)), goalMl: 2000, goalReached: true))
        try container.mainContext.save()
        store.addWater(amountMl: 2100)
        XCTAssertEqual(store.currentStreak, 2)
        let versionBefore = store.dataVersion

        store.setDailyGoal(2500)

        let today = try XCTUnwrap(store.fetchDayRecord(for: Date()))
        XCTAssertEqual(today.goalMl, 2500)
        XCTAssertFalse(today.goalReached)
        XCTAssertEqual(store.currentStreak, 1, "hier reste atteint, aujourd'hui ne l'est plus")
        XCTAssertEqual(try XCTUnwrap(store.fetchDayRecord(for: daysAgo(1))).goalMl, 2000,
                       "les jours passés gardent l'objectif de l'époque")
        XCTAssertGreaterThan(store.dataVersion, versionBefore)
    }

    // MARK: - Grille

    func testContributionRatios_windowNetWaterAndRecordOnlyDays() throws {
        let cal = Calendar.current
        store.addWater(amountMl: 1000, date: daysAgo(2))
        store.addAlcohol(amountMl: 330, type: .beer, date: daysAgo(2))
        store.addWater(amountMl: 2000, date: daysAgo(500))
        container.mainContext.insert(DayRecord(date: cal.startOfDay(for: daysAgo(10)), goalMl: 2000, goalReached: true))
        try container.mainContext.save()

        let ratios = store.contributionRatios(days: 365)

        let twoDaysAgo = try XCTUnwrap(ratios[cal.startOfDay(for: daysAgo(2))])
        XCTAssertLessThan(twoDaysAgo, 0.5, "la compensation alcool est déduite")
        XCTAssertEqual(ratios[cal.startOfDay(for: daysAgo(10))], 1.0, "jour atteint sans entrée d'eau conservée")
        XCTAssertNil(ratios[cal.startOfDay(for: daysAgo(500))], "hors de la fenêtre")
        XCTAssertNotNil(ratios[cal.startOfDay(for: Date())])
    }
}
