import XCTest
import SwiftData
@testable import AquApp

/// Un an d'utilisation (~2 900 verres). Les mesures s'affichent dans le rapport de tests ;
/// fixer une baseline dans Xcode pour qu'une régression fasse échouer le test.
@MainActor
final class PerformanceTests: XCTestCase {

    private var container: ModelContainer!
    private var store: AppDataStore!

    override func setUp() async throws {
        try await super.setUp()
        HealthDataManager.shared.resetForTests()
        let cal = Calendar.current
        container = try ModelContainer(
            for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = container.mainContext
        let today = cal.startOfDay(for: Date())
        for d in 1...365 {
            let day = cal.date(byAdding: .day, value: -d, to: today)!
            for h in 0..<8 {
                ctx.insert(WaterEntry(amountMl: 300, date: day.addingTimeInterval(Double(8 + h * 2) * 3600)))
            }
            if d % 7 == 0 {
                ctx.insert(WaterAlcoholEntry(amountMl: 330, alcoholType: .beer, date: day.addingTimeInterval(20 * 3600)))
            }
            ctx.insert(DayRecord(date: day, goalMl: 2000, goalReached: true))
        }
        try ctx.save()
        store = AppDataStore(modelContext: ctx)
        store.dailyGoalMl = 2000
        _ = store.activeDaysTotal
    }

    override func tearDown() async throws {
        store = nil
        container = nil
        try await super.tearDown()
    }

    func testAddWater_oneYearOfData() {
        measure { store.addWater(amountMl: 100) }
    }

    func testContributionGrid_oneYearOfData() {
        measure { _ = store.contributionRatios(days: 400) }
    }

    func testActiveDaysTotal_isCachedAfterFirstRead() {
        measure { _ = store.activeDaysTotal }
    }
}
