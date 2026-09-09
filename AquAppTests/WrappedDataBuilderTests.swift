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

    // MARK: - Cas vide

    func testEmptyYear_AllZeroes() {
        let w = WrappedDataBuilder.build(
            store: store, xpManager: xpManager, achievementManager: achievementManager,
            challengeManager: challengeManager, modelContext: container.mainContext
        )
        XCTAssertEqual(w.totalLiters, 0)
        XCTAssertEqual(w.totalGlasses, 0)
        XCTAssertEqual(w.avgDailyMl, 0)
        XCTAssertEqual(w.goalDays, 0)
        XCTAssertEqual(w.bestStreak, 0)
        XCTAssertEqual(w.alcoholLiters, 0)
        XCTAssertEqual(w.monthlyTotals.count, 12)
        XCTAssertEqual(w.monthLabels.count, 12)
    }

    // MARK: - Total eau & verres (250 ml = 1 verre)

    func testTotalWater_GlassesCalculation() {
        let today = Date()
        store.addWater(amountMl: 250, date: today)
        store.addWater(amountMl: 250, date: today)
        store.addWater(amountMl: 250, date: today)
        store.addWater(amountMl: 125, date: today) // demi-verre, pas compté

        let w = WrappedDataBuilder.build(
            store: store, xpManager: xpManager, achievementManager: achievementManager,
            challengeManager: challengeManager, modelContext: container.mainContext
        )
        XCTAssertEqual(w.totalLiters, 0.875, accuracy: 0.0001)
        XCTAssertEqual(w.totalGlasses, 3) // 875 / 250 = 3 (troncature)
    }

    // MARK: - Moyenne journalière (jours actifs)

    func testAvgDailyMl_ActiveDays() {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = today.addingTimeInterval(-86400)
        store.addWater(amountMl: 1000, date: today)
        store.addWater(amountMl: 2000, date: yesterday)
        let w = WrappedDataBuilder.build(
            store: store, xpManager: xpManager, achievementManager: achievementManager,
            challengeManager: challengeManager, modelContext: container.mainContext
        )
        XCTAssertEqual(w.avgDailyMl, 1500, accuracy: 0.01)
    }

    // MARK: - Meilleur mois

    func testBestMonth_IdentifiedCorrectly() {
        let cal = Calendar.current
        let currentMonth = cal.component(.month, from: Date())
        // Met beaucoup d'eau dans le mois courant
        for day in 0..<10 {
            let d = cal.date(byAdding: .day, value: -day, to: Date())!
            store.addWater(amountMl: 500, date: d)
        }
        let w = WrappedDataBuilder.build(
            store: store, xpManager: xpManager, achievementManager: achievementManager,
            challengeManager: challengeManager, modelContext: container.mainContext
        )
        XCTAssertEqual(w.bestMonthLiters, 5, accuracy: 0.01)
    }

    // MARK: - Objectifs atteints

    func testGoalDays_CountsReachedRecords() {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = today.addingTimeInterval(-86400)
        let ctx = container.mainContext
        ctx.insert(DayRecord(date: today, goalMl: 2000, goalReached: true))
        ctx.insert(DayRecord(date: yesterday, goalMl: 2000, goalReached: true))
        try? ctx.save()

        let w = WrappedDataBuilder.build(
            store: store, xpManager: xpManager, achievementManager: achievementManager,
            challengeManager: challengeManager, modelContext: ctx
        )
        XCTAssertEqual(w.goalDays, 2)
    }

    // MARK: - Meilleur streak (série consécutive)

    func testBestStreak_ConsecutiveDays() {
        let today = Calendar.current.startOfDay(for: Date())
        let ctx = container.mainContext
        for i in 0..<5 {
            let d = today.addingTimeInterval(Double(-i) * 86400)
            ctx.insert(DayRecord(date: d, goalMl: 2000, goalReached: true))
        }
        // Trou cassée à J-6
        ctx.insert(DayRecord(date: today.addingTimeInterval(-6 * 86400), goalMl: 2000, goalReached: false))
        try? ctx.save()

        let w = WrappedDataBuilder.build(
            store: store, xpManager: xpManager, achievementManager: achievementManager,
            challengeManager: challengeManager, modelContext: ctx
        )
        XCTAssertEqual(w.bestStreak, 5)
    }

    // MARK: - Jours sobres

    func testSoberDays_TotalMinusAlcoholDays() {
        store.addAlcohol(amountMl: 250, type: .beer)
        let w = WrappedDataBuilder.build(
            store: store, xpManager: xpManager, achievementManager: achievementManager,
            challengeManager: challengeManager, modelContext: container.mainContext
        )
        // Au moins 1 jour sobre soustrait
        XCTAssertLessThanOrEqual(w.soberDays, 364)
    }

    // MARK: - Alcool

    func testAlcohol_TotalLiters() {
        store.addAlcohol(amountMl: 500, type: .beer)
        store.addAlcohol(amountMl: 500, type: .wine)
        let w = WrappedDataBuilder.build(
            store: store, xpManager: xpManager, achievementManager: achievementManager,
            challengeManager: challengeManager, modelContext: container.mainContext
        )
        XCTAssertEqual(w.alcoholLiters, 1.0, accuracy: 0.01)
    }

    // MARK: - Habitudes matinales (avant 9h)

    func testMorningDays_CountsBefore9AM() {
        let early = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        let late  = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        store.addWater(amountMl: 250, date: early)
        store.addWater(amountMl: 250, date: late)
        let w = WrappedDataBuilder.build(
            store: store, xpManager: xpManager, achievementManager: achievementManager,
            challengeManager: challengeManager, modelContext: container.mainContext
        )
        XCTAssertEqual(w.morningDays, 1)
    }

    // MARK: - Canicule (jours > 3000 ml)

    func testHeatwaveDays_FromUserDefaults() {
        UserDefaults.standard.set(5.0, forKey: "heatwave_days")
        let w = WrappedDataBuilder.build(
            store: store, xpManager: xpManager, achievementManager: achievementManager,
            challengeManager: challengeManager, modelContext: container.mainContext
        )
        XCTAssertEqual(w.heatwaveDays, 5)
    }

    // MARK: - Monthly totals (12 mois)

    func testMonthlyTotals_Always12Values() {
        let w = WrappedDataBuilder.build(
            store: store, xpManager: xpManager, achievementManager: achievementManager,
            challengeManager: challengeManager, modelContext: container.mainContext
        )
        XCTAssertEqual(w.monthlyTotals.count, 12)
        XCTAssertEqual(w.monthLabels.count, 12)
        // Tous les mois sans données = 0
        XCTAssertEqual(w.monthlyTotals.reduce(0, +), 0, accuracy: 0.0001)
    }
}