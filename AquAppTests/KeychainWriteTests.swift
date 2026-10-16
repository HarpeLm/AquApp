import XCTest
import SwiftData
@testable import AquApp

/// Chaque écriture dans le Trousseau supprime puis recrée l'élément : c'est lent et ça
/// coûte de la batterie. Un ajout d'eau en déclenchait des centaines (succès réécrits un
/// par un à chaque mise à jour) ; il doit rester sous quelques écritures.
@MainActor
final class KeychainWriteTests: XCTestCase {

    private var container: ModelContainer!
    private var store: AppDataStore!
    private var achievements: AchievementManager!
    private var challenges: ChallengeManager!
    private var xp: XPManager!

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
        xp = XPManager()
        achievements = AchievementManager()
        challenges = ChallengeManager()
        store.xpManager = xp
        store.achievementManager = achievements
        store.challengeManager = challenges
        achievements.xpManager = xp
        challenges.xpManager = xp
    }

    override func tearDown() async throws {
        try? await Task.sleep(for: .seconds(0.3)) // callbacks HealthKit des gestionnaires
        store = nil
        container = nil
        HealthDataManager.shared.resetForTests()
        try await super.tearDown()
    }

    private func writes(during work: () -> Void) -> Int {
        let before = KeychainManager.writeCount
        work()
        return KeychainManager.writeCount - before
    }

    // MARK: - Ajout d'eau

    func testAddingWater_staysUnderAFewKeychainWrites() {
        store.addWater(amountMl: 250)   // premier ajout : séries, XP, succès démarrent

        let count = writes { store.addWater(amountMl: 250) }
        print("📊 Écritures Trousseau pour un ajout d'eau : \(count)")

        // total d'eau, XP, progression des succès… : quelques écritures, pas des centaines
        XCTAssertLessThanOrEqual(count, 6, "\(count) écritures pour un seul ajout d'eau")
    }

    func testAddingWaterTenTimes_staysLinearAndSmall() {
        let count = writes {
            for _ in 0..<10 { store.addWater(amountMl: 200) }
        }
        XCTAssertLessThanOrEqual(count, 60, "\(count) écritures pour 10 ajouts")
    }

    // MARK: - Valeurs inchangées

    func testSettingTheSameValue_doesNotWrite() {
        let health = HealthDataManager.shared
        health.setCurrentStreak(4)
        health.setXPTotal(120)
        health.setTotalWaterMl(1500)
        health.setFirstName("Camille")
        health.setAchievementProgress("constance", value: 2)

        let count = writes {
            health.setCurrentStreak(4)
            health.setXPTotal(120)
            health.setTotalWaterMl(1500)
            health.setFirstName("Camille")
            health.setAchievementProgress("constance", value: 2)
        }
        XCTAssertEqual(count, 0)
    }

    func testChangedValues_areStillSaved() {
        let health = HealthDataManager.shared
        health.setCurrentStreak(9)
        health.setXPTotal(345)
        health.setFirstName("Léa")

        XCTAssertEqual(KeychainManager.shared.getDouble(forKey: "current_streak"), 9)
        XCTAssertEqual(KeychainManager.shared.getDouble(forKey: "xp_total"), 345)
        XCTAssertEqual(KeychainManager.shared.getString(forKey: "userFirstName"), "Léa")
    }

    // MARK: - Succès en lot

    func testAchievementBatch_writesEachDictionaryAtMostOnce() {
        let health = HealthDataManager.shared
        let count = writes {
            health.setAchievementStates(
                progress: ["constance": 3, "centurion": 12, "legende": 4_000],
                completed: ["constance": false, "centurion": false, "legende": false]
            )
        }
        XCTAssertLessThanOrEqual(count, 2)
        XCTAssertEqual(health.achievementProgressValue("centurion"), 12)
    }

    func testAchievementBatch_withoutChanges_doesNotWrite() {
        let health = HealthDataManager.shared
        health.setAchievementStates(progress: ["constance": 5], completed: ["constance": false])
        let count = writes {
            health.setAchievementStates(progress: ["constance": 5], completed: ["constance": false])
        }
        XCTAssertEqual(count, 0)
    }

    func testAchievementProgress_survivesInTheKeychain() throws {
        HealthDataManager.shared.setAchievementStates(progress: ["perfect_week": 6], completed: ["iron_month": true])
        let progressJSON = try XCTUnwrap(KeychainManager.shared.getString(forKey: "ach_progress_dict"))
        let completedJSON = try XCTUnwrap(KeychainManager.shared.getString(forKey: "ach_completed_dict"))
        let progress = try JSONDecoder().decode([String: Double].self, from: Data(progressJSON.utf8))
        let completed = try JSONDecoder().decode([String: Bool].self, from: Data(completedJSON.utf8))
        XCTAssertEqual(progress["perfect_week"], 6)
        XCTAssertEqual(completed["iron_month"], true)
    }

    // MARK: - Remise à zéro de test

    func testResetForTests_writesEvenWhenMemoryAlreadyMatches() {
        HealthDataManager.shared.resetForTests()
        KeychainManager.shared.delete(forKey: "xp_total")
        HealthDataManager.shared.resetForTests()
        XCTAssertEqual(KeychainManager.shared.getDouble(forKey: "xp_total"), 0)
    }
}
