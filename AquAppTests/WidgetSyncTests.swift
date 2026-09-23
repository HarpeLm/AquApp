import XCTest
import SwiftData
@testable import AquApp

@MainActor
final class WidgetSyncTests: XCTestCase {

    private var container: ModelContainer!
    private var store: AppDataStore!
    private let defaults = UserDefaults(suiteName: WidgetBridge.appGroup)!

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

    func testAddWater_reachingGoal_widgetGetsNewStreak() {
        store.addWater(amountMl: 2000)

        XCTAssertEqual(store.currentStreak, 1)
        XCTAssertEqual(defaults.integer(forKey: "widget_streak"), 1,
                       "le widget doit recevoir la série recalculée, pas l'ancienne")
        XCTAssertEqual(defaults.double(forKey: "widget_today_ml"), 2000)
    }

    func testAddAlcohol_widgetGetsSoberStreakReset() {
        HealthDataManager.shared.setSoberStreak(5)

        store.addAlcohol(amountMl: 330, type: .beer)

        XCTAssertEqual(store.soberDaysStreak, 0)
        XCTAssertEqual(defaults.integer(forKey: "widget_sober_streak"), 0)
    }

    func testFlushPendingEntries_insertsValidAndSkipsInvalid() {
        let now = Date().timeIntervalSince1970
        defaults.set([
            ["amountMl": 250.0, "timestamp": now, "siriIntentID": "a"],
            ["amountMl": -5.0, "timestamp": now],
            ["amountMl": 9000.0, "timestamp": now],
            ["amountMl": 330.0, "timestamp": now, "isAlcohol": true, "alcoholKindRaw": AlcoholKind.beer.rawValue],
        ], forKey: "widget_pending_entries")

        store.flushWidgetPendingEntries()

        XCTAssertEqual(store.todayWaterEntries().count, 1, "les volumes invalides sont rejetés")
        XCTAssertEqual(store.todayAlcoholEntries().count, 1)
        XCTAssertNil(defaults.array(forKey: "widget_pending_entries"), "la file doit être vidée")
    }
}
