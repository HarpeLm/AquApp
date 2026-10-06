import XCTest
import SwiftData
@testable import AquApp

@MainActor
final class SiriIntentTests: XCTestCase {

    private var container: ModelContainer!
    private var store: AppDataStore!

    override func setUp() async throws {
        try await super.setUp()
        HealthDataManager.shared.resetForTests()
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
        try await super.tearDown()
    }

    func testAddWater_goesThroughStorePipeline() {
        let reply = IntentActions.addWater(300, store: store)

        XCTAssertEqual(store.todayWaterMl, 300)
        XCTAssertEqual(store.todayWaterEntries().count, 1)
        XCTAssertTrue(reply.contains(UnitFormatter.volume(300)), reply)
        XCTAssertTrue(reply.contains(UnitFormatter.volume(2000)), "la réponse rappelle l'objectif : \(reply)")
    }

    func testAddWater_reachingGoal_updatesStreak() {
        _ = IntentActions.addWater(2000, store: store)
        XCTAssertEqual(store.currentStreak, 1)
    }

    func testAddAlcohol_usesDefaultServingAndReportsCompensation() throws {
        let reply = IntentActions.addAlcohol(.wine, amountMl: nil, store: store)

        let entry = try XCTUnwrap(store.todayAlcoholEntries().first)
        XCTAssertEqual(entry.amountMl, Double(AlcoholKind.wine.defaultServingMl))
        XCTAssertEqual(store.soberDaysStreak, 0)
        XCTAssertTrue(reply.contains(UnitFormatter.volume(entry.compensationMl)), reply)
    }

    func testAddAlcohol_explicitAmountWins() throws {
        _ = IntentActions.addAlcohol(.beer, amountMl: 500, store: store)
        XCTAssertEqual(try XCTUnwrap(store.todayAlcoholEntries().first).amountMl, 500)
    }

    func testTodayProgress_beforeAndAfterGoal() {
        store.addWater(amountMl: 500)
        XCTAssertTrue(IntentActions.todayProgress(store: store).contains("25"), "500/2000 = 25 %")

        store.addWater(amountMl: 1500)
        let reached = IntentActions.todayProgress(store: store)
        XCTAssertEqual(reached, String(format: String(localized: "intent.today.goal_reached"),
                                       UnitFormatter.volume(2000), UnitFormatter.volume(2000)))
    }
}
