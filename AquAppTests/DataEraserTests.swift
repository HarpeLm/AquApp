import XCTest
import SwiftData
@testable import AquApp

/// « Supprimer mes données » : tout ce qu'AquApp garde doit disparaître,
/// et l'app doit repartir comme au premier lancement.
@MainActor
final class DataEraserTests: XCTestCase {

    private let suite = "test.aquapp.eraser"
    private let groupSuite = "test.aquapp.eraser.group"

    private var container: ModelContainer!
    private var store: AppDataStore!
    private var xp: XPManager!
    private var achievements: AchievementManager!
    private var challenges: ChallengeManager!
    private var defaults: UserDefaults!
    private var groupDefaults: UserDefaults!

    private var notificationsRemoved = false
    private var photoRemoved = false

    override func setUp() async throws {
        try await super.setUp()
        HealthDataManager.shared.resetForTests()
        PremiumManager.shared.resetForTests(false)

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

        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        groupDefaults = UserDefaults(suiteName: groupSuite)
        groupDefaults.removePersistentDomain(forName: groupSuite)

        notificationsRemoved = false
        photoRemoved = false
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        groupDefaults.removePersistentDomain(forName: groupSuite)
        PremiumManager.shared.resetForTests(false)
        HealthDataManager.shared.resetForTests()
        store = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Un utilisateur qui se sert de l'app depuis un moment.
    private func seedUsedApp() {
        let calendar = Calendar.current
        for daysAgo in 0..<5 {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
            store.addWater(amountMl: 2100, date: day)
        }
        store.addAlcohol(amountMl: 250, type: .beer)

        let health = HealthDataManager.shared
        health.setFirstName("Camille")
        health.setWeight(82)
        health.setHeight(181)
        health.setGender("female")
        health.setXPTotal(640)
        health.setAchievementProgress("constance", value: 7)
        health.setAchievementCompleted("constance", value: true)
        health.setChallengeCompleted("matinal", value: true)
        health.setPrunedAlcoholDate(Date(timeIntervalSinceNow: -86_400 * 40))
        health.setFirstLaunchDate(Date(timeIntervalSinceNow: -86_400 * 90))

        defaults.set(true, forKey: DataEraser.onboardingKey)
        defaults.set(9, forKey: "notifStartHour")
        defaults.set(true, forKey: "notificationsOn")
        defaults.set(Data([1, 2, 3]), forKey: CustomDrinkStore.key)
        defaults.set(12, forKey: "xp_water_today_20261015")
        groupDefaults.set(1800.0, forKey: "widget_today_ml")
        groupDefaults.set(5, forKey: "widget_streak")
    }

    /// `standardDefaults` : les défis lisent leur progression dans les vrais réglages de l'app
    /// (restaurés après la suite par TestEnvironmentGuard).
    private func erase(includeHealthData: Bool = false, standardDefaults: Bool = false) async {
        await DataEraser.eraseAll(
            store: store,
            xpManager: xp,
            achievementManager: achievements,
            challengeManager: challenges,
            options: .init(includeHealthData: includeHealthData),
            defaults: standardDefaults ? .standard : defaults,
            appDomain: standardDefaults ? (Bundle.main.bundleIdentifier ?? "") : suite,
            groupDefaults: groupDefaults,
            groupDomain: groupSuite,
            removeNotifications: { self.notificationsRemoved = true },
            removeProfilePhoto: { self.photoRemoved = true }
        )
    }

    // MARK: - Base de données

    func testErase_deletesAllEntriesAndDayRecords() async throws {
        seedUsedApp()
        XCTAssertFalse(store.allWaterEntries().isEmpty)

        await erase()

        XCTAssertTrue(store.allWaterEntries().isEmpty)
        XCTAssertTrue(store.allAlcoholEntries().isEmpty)
        XCTAssertEqual(store.todayWaterMl, 0)
        XCTAssertEqual(store.todayAlcoholMl, 0)
        let records = try container.mainContext.fetch(FetchDescriptor<DayRecord>())
        XCTAssertTrue(records.isEmpty, "l'effacement ne doit pas recréer de DayRecord")
    }

    // MARK: - Trousseau

    func testErase_removesPersonalDataFromKeychain() async {
        seedUsedApp()

        await erase()

        let km = KeychainManager.shared
        for key in ["userFirstName", "userGender", "ach_progress_dict", "ach_completed_dict", "completed_dict"] {
            XCTAssertNil(km.getString(forKey: key), key)
        }
        for key in ["userWeightKg", "userHeightCm", "pruned_alcohol_date"] {
            XCTAssertNil(km.getDouble(forKey: key), key)
        }
        // Les compteurs peuvent être réécrits à 0 par le recalcul des séries, comme au premier lancement
        for key in ["xp_total", "current_streak", "total_goal_days", "total_water_ml", "total_alcohol_ml"] {
            XCTAssertEqual(km.getDouble(forKey: key) ?? 0, 0, key)
        }
    }

    func testErase_keepsPremiumStatus() async {
        PremiumManager.shared.set(true)
        seedUsedApp()

        await erase()

        XCTAssertTrue(PremiumManager.shared.isPremium)
        XCTAssertEqual(KeychainManager.shared.getBool(forKey: "isPremiumUser"), true)
    }

    func testErase_keepsFreeStatusFree() async {
        seedUsedApp()
        await erase()
        XCTAssertFalse(PremiumManager.shared.isPremium)
    }

    // MARK: - État en mémoire

    func testErase_resetsProfileAndCountersInMemory() async {
        seedUsedApp()

        await erase()

        let health = HealthDataManager.shared
        XCTAssertEqual(health.firstName, "")
        XCTAssertEqual(health.weightKg, 70)
        XCTAssertEqual(health.heightCm, 170)
        XCTAssertEqual(health.gender, "notSpecified")
        XCTAssertEqual(health.xpTotal, 0)
        XCTAssertEqual(health.currentStreak, 0)
        XCTAssertEqual(health.totalGoalDays, 0)
        XCTAssertEqual(health.totalWaterMl, 0)
        XCTAssertEqual(health.totalAlcoholMl, 0)
        XCTAssertNil(health.prunedAlcoholDate)
        XCTAssertTrue(health.achievementProgress.isEmpty)
        XCTAssertTrue(health.achievementCompleted.isEmpty)
        XCTAssertTrue(health.challengeCompleted.isEmpty)
    }

    func testErase_restartsTheInstallDate() async {
        seedUsedApp()
        await erase()
        XCTAssertEqual(HealthDataManager.shared.firstLaunchDate.timeIntervalSinceNow, 0, accuracy: 5)
    }

    func testErase_resetsXPAchievementsAndChallenges() async {
        seedUsedApp()
        xp.reloadAfterErase()   // l'XP semée est visible avant l'effacement
        XCTAssertEqual(xp.totalXP, 640)

        await erase(standardDefaults: true)

        XCTAssertEqual(xp.totalXP, 0)
        XCTAssertEqual(xp.currentLevel, XPLevel.level(for: 0))
        XCTAssertNil(xp.lastGain)
        XCTAssertFalse(achievements.achievements.contains { $0.status == .completed })
        for a in achievements.achievements + achievements.monthlyAchievements {
            XCTAssertEqual(a.currentProgress, 0, "succès \(a.id)")
        }
        for c in challenges.challenges {
            XCTAssertEqual(c.currentProgress, 0, "défi \(c.id)")
            XCTAssertNotEqual(c.status, .completed, "défi \(c.id)")
        }
    }

    func testErase_streaksStartOverLikeAFreshInstall() async {
        seedUsedApp()
        XCTAssertGreaterThan(store.currentStreak, 0)

        await erase()

        XCTAssertEqual(store.currentStreak, 0)
        XCTAssertEqual(store.totalGoalDays, 0)
        XCTAssertLessThanOrEqual(store.soberDaysStreak, 1, "au plus le jour d'installation")
    }

    // MARK: - Réglages, widget, fichiers, rappels

    func testErase_clearsSettingsAndShowsOnboardingAgain() async {
        seedUsedApp()

        await erase()

        XCTAssertFalse(defaults.bool(forKey: DataEraser.onboardingKey))
        XCTAssertNil(defaults.object(forKey: "notifStartHour"))
        XCTAssertNil(defaults.object(forKey: "notificationsOn"))
        XCTAssertNil(defaults.object(forKey: CustomDrinkStore.key))
        XCTAssertNil(defaults.object(forKey: "xp_water_today_20261015"))
        XCTAssertTrue(defaults.persistentDomain(forName: suite)?.isEmpty ?? true)
    }

    func testErase_clearsWidgetSharedData() async {
        seedUsedApp()

        await erase()

        XCTAssertNil(groupDefaults.object(forKey: "widget_today_ml"))
        XCTAssertNil(groupDefaults.object(forKey: "widget_streak"))
    }

    func testErase_removesRemindersAndProfilePhoto() async {
        seedUsedApp()

        await erase()

        XCTAssertTrue(notificationsRemoved)
        XCTAssertTrue(photoRemoved)
    }

    // MARK: - Robustesse

    func testErase_withHealthOption_doesNotFailWithoutHealthAccess() async {
        seedUsedApp()
        await erase(includeHealthData: true)
        XCTAssertTrue(store.allWaterEntries().isEmpty)
    }

    func testErase_onAFreshApp_isHarmless() async {
        await erase()
        await erase()
        XCTAssertTrue(store.allWaterEntries().isEmpty)
        XCTAssertEqual(HealthDataManager.shared.firstName, "")
    }

    func testApp_isUsableAgainAfterErase() async {
        seedUsedApp()
        await erase()

        store.addWater(amountMl: 500)

        XCTAssertEqual(store.todayWaterMl, 500)
        XCTAssertEqual(store.allWaterEntries().count, 1)
        XCTAssertEqual(HealthDataManager.shared.totalWaterMl, 500)
    }

    // MARK: - Interface

    func testEraseStrings_areTranslated() throws {
        for language in ["fr", "en"] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            for key in ["privacy.section.title", "privacy.policy", "privacy.erase.button",
                        "privacy.erase.confirm.title", "profile.more_options",
                        "privacy.erase.confirm.message", "privacy.erase.confirm.app_only",
                        "privacy.erase.confirm.with_health", "privacy.erase.confirm.cancel"] {
                let value = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
                XCTAssertNotEqual(value, key, "\(key) manquant en \(language)")
            }
        }
    }
}
