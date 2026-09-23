import XCTest
import SwiftData
@testable import AquApp

@MainActor
final class StreakTests: XCTestCase {

    private var container: ModelContainer!
    private var store: AppDataStore!

    override func setUp() async throws {
        try await super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
            configurations: config
        )
        HealthDataManager.shared.resetForTests()
        HealthDataManager.shared.setFirstLaunchDate(daysAgo(10))
        store = AppDataStore(modelContext: container.mainContext)
    }

    override func tearDown() async throws {
        store = nil
        container = nil
        try await super.tearDown()
    }

    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date())!
    }

    private func insertAlcohol(daysAgo n: Int) throws {
        container.mainContext.insert(WaterAlcoholEntry(amountMl: 250, alcoholType: .wine, date: daysAgo(n)))
        try container.mainContext.save()
    }

    // MARK: - Streak sobre

    func testSoberStreak_multipleCallsInSameDay_doesNotIncrement() throws {
        try insertAlcohol(daysAgo: 5)

        for _ in 0..<10 {
            store.recalculateSoberStreak()
        }

        XCTAssertEqual(store.soberDaysStreak, 5,
            "Recalculer plusieurs fois dans la journée ne doit rien changer")
    }

    func testSoberStreak_noAlcoholEver_countsFromInstallDay() {
        store.recalculateSoberStreak()
        XCTAssertEqual(store.soberDaysStreak, 11, "10 jours d'historique + aujourd'hui")
    }

    func testSoberStreak_alcoholYesterday_isOne() throws {
        try insertAlcohol(daysAgo: 1)
        store.recalculateSoberStreak()
        XCTAssertEqual(store.soberDaysStreak, 1)
    }

    func testSoberStreak_alcoholToday_resetsToZero() throws {
        try insertAlcohol(daysAgo: 0)

        store.recalculateSoberStreak()

        XCTAssertEqual(store.soberDaysStreak, 0)
    }

    func testSoberStreak_deleteAlcoholToday_recalculatesFromYesterday() throws {
        try insertAlcohol(daysAgo: 4)
        store.addAlcohol(amountMl: 250, type: .wine)
        XCTAssertEqual(store.soberDaysStreak, 0, "Avec alcool → streak 0")

        store.deleteAlcohol(try XCTUnwrap(store.todayAlcoholEntries().first))

        XCTAssertEqual(store.soberDaysStreak, 4, "Supprimer une saisie par erreur doit restaurer la série")
    }

    func testSoberStreak_survivesNonPremiumCleanup() throws {
        HealthDataManager.shared.setFirstLaunchDate(daysAgo(100))
        try insertAlcohol(daysAgo: 40)
        store.isPremiumUser = false

        store.cleanOldDataIfNeeded()
        store.recalculateSoberStreak()

        XCTAssertTrue(store.allAlcoholEntries().isEmpty, "précondition : l'entrée a bien été supprimée")
        XCTAssertEqual(store.soberDaysStreak, 40, "la série ne doit pas remonter jusqu'à l'installation")
    }

    // MARK: - Streak objectif

    func testGoalStreak_heatwave_usesEffectiveGoal() throws {
        store.dailyGoalMl = 2000
        store.heatwaveGoalMl = 2500

        let entry = WaterEntry(amountMl: 2300, date: Date())
        container.mainContext.insert(entry)
        try container.mainContext.save()

        store.recalculateGoalStreak()

        XCTAssertFalse(store.todayGoalReached)
        XCTAssertEqual(store.currentStreak, 0,
            "Avec canicule active, 2300ml ne doit PAS atteindre l'objectif de 2500ml")
    }

    func testGoalStreak_heatwave_aboveHeatwaveGoal_counts() throws {
        store.dailyGoalMl = 2000
        store.heatwaveGoalMl = 2500

        let entry = WaterEntry(amountMl: 2600, date: Date())
        container.mainContext.insert(entry)
        try container.mainContext.save()

        store.recalculateGoalStreak()

        XCTAssertTrue(store.todayGoalReached)
        XCTAssertEqual(store.currentStreak, 1)
    }

    // MARK: - DayRecord

    func testDayRecord_todaySavesEffectiveGoal() throws {
        store.dailyGoalMl = 2000
        store.heatwaveGoalMl = 2500

        let entry = WaterEntry(amountMl: 2600, date: Date())
        container.mainContext.insert(entry)
        try container.mainContext.save()

        store.recalculateGoalStreak()

        let today = Calendar.current.startOfDay(for: Date())
        guard let record = store.fetchDayRecord(for: today) else {
            XCTFail("DayRecord doit exister pour aujourd'hui")
            return
        }

        XCTAssertEqual(record.goalMl, 2500,
            "Le DayRecord du jour doit sauvegarder effectiveGoalMl (canicule)")
        XCTAssertTrue(record.goalReached)
    }

    func testDayRecord_pastDayKeepsDailyGoal() throws {
        store.dailyGoalMl = 2000
        store.heatwaveGoalMl = 2500

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let entry = WaterEntry(amountMl: 2100, date: yesterday)
        container.mainContext.insert(entry)

        let yesterdayStart = Calendar.current.startOfDay(for: yesterday)
        let record = DayRecord(date: yesterdayStart, goalMl: 2000, goalReached: true)
        container.mainContext.insert(record)
        try container.mainContext.save()

        guard let fetched = store.fetchDayRecord(for: yesterdayStart) else {
            XCTFail("DayRecord hier introuvable")
            return
        }
        XCTAssertEqual(fetched.goalMl, 2000)
    }
}
