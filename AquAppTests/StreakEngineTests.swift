import XCTest
import SwiftData
@testable import AquApp

@MainActor
final class StreakEngineTests: XCTestCase {

    private var container: ModelContainer!
    private var store: AppDataStore!

    override func setUp() async throws {
        try await super.setUp()
        HealthDataManager.shared.resetForTests()
        UserDefaults.standard.removeObject(forKey: StreakEngine.lastSoberRecalcKey)
        container = try ModelContainer(
            for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = AppDataStore(modelContext: container.mainContext)
        store.dailyGoalMl = 2000
        store.heatwaveGoalMl = nil
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: StreakEngine.lastSoberRecalcKey)
        store = nil
        container = nil
        try await super.tearDown()
    }

    func testGoalStreak_usesNetWater_alcoholCanDropBelowGoal() {
        store.addWater(amountMl: 2000)
        XCTAssertEqual(store.currentStreak, 1)

        store.addAlcohol(amountMl: 330, type: .beer)

        XCTAssertFalse(store.todayGoalReached)
        XCTAssertEqual(store.currentStreak, 0,
                       "la série doit suivre l'eau nette, comme l'accueil et les DayRecord")
    }

    func testHeatwaveGoalChange_updatesTodayRecordStreakAndWidget() throws {
        store.addWater(amountMl: 2100)
        XCTAssertEqual(store.currentStreak, 1)

        store.heatwaveGoalMl = 2500

        let record = try XCTUnwrap(store.fetchDayRecord(for: Date()))
        XCTAssertEqual(record.goalMl, 2500)
        XCTAssertFalse(record.goalReached)
        XCTAssertEqual(store.currentStreak, 0)
        XCTAssertEqual(UserDefaults(suiteName: WidgetBridge.appGroup)?.double(forKey: "widget_goal_ml"), 2500)
    }

    func testRecalculateGoalStreak_seesEntriesWrittenOutsideTheStore() throws {
        container.mainContext.insert(WaterEntry(amountMl: 2000, date: Date()))
        try container.mainContext.save()

        store.recalculateGoalStreak()

        XCTAssertTrue(store.todayGoalReached)
        XCTAssertEqual(store.currentStreak, 1)
    }
}
