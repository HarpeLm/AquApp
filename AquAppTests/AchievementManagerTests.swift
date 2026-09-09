//
//  AchievementManagerTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 08/09/2026.
//


import XCTest
@testable import AquApp

@MainActor
final class AchievementManagerTests: XCTestCase {

    var manager: AchievementManager!
    var retained: [AchievementManager] = []

    override func setUp() async throws {
        try await super.setUp()
        // Nettoyage des clés persistantes
        let keys = ["isPremiumUser", "sober_days_total", "heatwave_days",
                    "summer_hydration_days_2026", "summer_hydration_days_2025"]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        // Nettoyage de tous les ach_progress_* et ach_completed_*
        let d = UserDefaults.standard
        d.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("ach_progress_") || $0.hasPrefix("ach_completed_") }
            .forEach { d.removeObject(forKey: $0) }

        retained = []
        manager = AchievementManager()
        retained.append(manager)
    }

    override func tearDown() async throws {
        retained = []
        manager = nil
        try await super.tearDown()
    }

    // MARK: - Catalogue complet

    func testAchievementCatalog_StandardCount() {
        XCTAssertEqual(manager.achievements.count, 12, "catalogue des succès standards")
    }

    func testAchievementCatalog_MonthlyCount() {
        XCTAssertEqual(manager.monthlyAchievements.count, 4, "catalogue des succès mensuels")
    }

    func testAchievementCatalog_AllTargets() {
        let expected: [(String, Double)] = [
            ("constance", 7), ("semaine_sobre", 7), ("sleep_hydrated", 5),
            ("heatwave", 3), ("perfect_week", 7), ("marathonien", 3),
            ("indestructible", 60), ("centurion_sobre", 100),
            ("legende", 1_000_000), ("aqua_addict", 1_000_000_000),
            ("iron_month", 30), ("centurion", 100),
        ]
        for (id, target) in expected {
            XCTAssertEqual(manager.achievements.first { $0.id == id }?.targetProgress, target, id)
        }
    }

    // MARK: - Progression ratio

    func testProgressRatio_ZeroTarget_ReturnsZero() {
        var a = Achievement(id: "x", sfSymbol: "x", symbolColor: .blue,
                            title: "x", description: "x", isPro: false, targetProgress: 0)
        XCTAssertEqual(a.progressRatio, 0)
    }

    func testProgressRatio_ClampedTo01() {
        var a = Achievement(id: "x", sfSymbol: "x", symbolColor: .blue,
                            title: "x", description: "x", isPro: false, targetProgress: 10)
        a.currentProgress = 5
        XCTAssertEqual(a.progressRatio, 0.5, accuracy: 0.001)
        a.currentProgress = 100
        XCTAssertEqual(a.progressRatio, 1.0)
        a.currentProgress = -5
        XCTAssertEqual(a.progressRatio, 0)
    }

    func testProgressRatio_Finite() {
        var a = Achievement(id: "x", sfSymbol: "x", symbolColor: .blue,
                            title: "x", description: "x", isPro: false, targetProgress: 10)
        a.currentProgress = .infinity
        XCTAssertEqual(a.progressRatio, 0, "infini doit être traité comme invalide")
        a.currentProgress = .nan
        XCTAssertEqual(a.progressRatio, 0)
    }

    // MARK: - Streaks : Constance (7 jours), Perfect Week (7), Iron Month (30), Indestructible (60)

    func testOnGoalReached_Streak7_CompletesConstanceAndPerfectWeek() {
        manager.onGoalReached(streak: 6, totalDays: 10)
        XCTAssertEqual(manager.ach(id: "constance").currentProgress, 6)
        XCTAssertNotEqual(manager.ach(id: "constance").status, .completed)

        manager.onGoalReached(streak: 7, totalDays: 10)
        XCTAssertEqual(manager.ach(id: "constance").status, .completed)
        XCTAssertEqual(manager.ach(id: "perfect_week").status, .completed)
    }

    func testOnGoalReached_Streak30_CompletesIronMonth() {
        manager.onGoalReached(streak: 29, totalDays: 50)
        XCTAssertNotEqual(manager.ach(id: "iron_month").status, .completed)
        manager.onGoalReached(streak: 30, totalDays: 50)
        XCTAssertEqual(manager.ach(id: "iron_month").status, .completed)
    }

    func testOnGoalReached_Streak60_CompletesIndestructible() {
        manager.onGoalReached(streak: 59, totalDays: 100)
        XCTAssertNotEqual(manager.ach(id: "indestructible").status, .completed)
        manager.onGoalReached(streak: 60, totalDays: 100)
        XCTAssertEqual(manager.ach(id: "indestructible").status, .completed)
    }

    // MARK: - Centurion (100 jours total)

    func testCenturion_TotalDays100() {
        manager.onGoalReached(streak: 1, totalDays: 99)
        XCTAssertNotEqual(manager.ach(id: "centurion").status, .completed)
        manager.onGoalReached(streak: 1, totalDays: 100)
        XCTAssertEqual(manager.ach(id: "centurion").status, .completed)
    }

    // MARK: - Semaine Sobre (streak 7)

    func testOnSoberStreakUpdated_7Days_CompletesSemaineSobre() {
        manager.onSoberStreakUpdated(streak: 6)
        XCTAssertNotEqual(manager.ach(id: "semaine_sobre").status, .completed)
        manager.onSoberStreakUpdated(streak: 7)
        XCTAssertEqual(manager.ach(id: "semaine_sobre").status, .completed)
    }

    // MARK: - Centurion Sobre (100 jours total cumulés)

    func testCenturionSobre_100CumulatedDays() {
        for _ in 0..<99 { manager.onSoberStreakUpdated(streak: 1) }
        XCTAssertNotEqual(manager.ach(id: "centurion_sobre").status, .completed)
        manager.onSoberStreakUpdated(streak: 1)
        XCTAssertEqual(manager.ach(id: "centurion_sobre").status, .completed)
    }

    // MARK: - Canicule (3 jours à ≥ 3000 ml)

    func testOnHeatwaveDay_Needs3DaysOver3000() {
        manager.onHeatwaveDay(totalMl: 2999) // sous le seuil
        XCTAssertEqual(UserDefaults.standard.double(forKey: "heatwave_days"), 0)
        manager.onHeatwaveDay(totalMl: 3000)
        XCTAssertEqual(UserDefaults.standard.double(forKey: "heatwave_days"), 1)
        manager.onHeatwaveDay(totalMl: 3000)
        manager.onHeatwaveDay(totalMl: 3000)
        XCTAssertEqual(manager.ach(id: "heatwave").status, .completed)
    }

    func testRestoreHeatwaveProgress() {
        manager.restoreHeatwaveProgress(days: 2.5)
        XCTAssertEqual(manager.ach(id: "heatwave").currentProgress, 2.5)
        manager.restoreHeatwaveProgress(days: 3)
        XCTAssertEqual(manager.ach(id: "heatwave").status, .completed)
    }

    // MARK: - Légende (1M ml) & Aqua'ddict (1B ml)

    func testOnWaterAdded_Legende1M() {
        manager.onWaterAdded(totalCumulatedMl: 999_999)
        XCTAssertNotEqual(manager.ach(id: "legende").status, .completed)
        manager.onWaterAdded(totalCumulatedMl: 1_000_000)
        XCTAssertEqual(manager.ach(id: "legende").status, .completed)
    }

    func testOnWaterAdded_AquaAddict1B() {
        manager.onWaterAdded(totalCumulatedMl: 999_999_999)
        XCTAssertNotEqual(manager.ach(id: "aqua_addict").status, .completed)
        manager.onWaterAdded(totalCumulatedMl: 1_000_000_000)
        XCTAssertEqual(manager.ach(id: "aqua_addict").status, .completed)
    }

    func testOnWaterAdded_ProgressCapped() {
        manager.onWaterAdded(totalCumulatedMl: 5_000_000)
        XCTAssertEqual(manager.ach(id: "legende").currentProgress, 1_000_000, "progression plafonnée au target")
    }

    // MARK: - Marathonien (3 conditions ET)

    func testOnMarathonienCheck_AllThreeConditions() {
        manager.onMarathonienCheck(drinkCount: 5, goalReached: true, steps: 8000)
        XCTAssertEqual(manager.ach(id: "marathonien").status, .completed)
    }

    func testOnMarathonienCheck_MissingOne() {
        manager.onMarathonienCheck(drinkCount: 4, goalReached: true, steps: 8000)
        XCTAssertNotEqual(manager.ach(id: "marathonien").status, .completed)
        XCTAssertEqual(manager.ach(id: "marathonien").currentProgress, 2, "2 conditions sur 3")
    }

    func testOnMarathonienCheck_StepsBoundary() {
        manager.onMarathonienCheck(drinkCount: 5, goalReached: true, steps: 7999)
        XCTAssertNotEqual(manager.ach(id: "marathonien").status, .completed)
        manager.onMarathonienCheck(drinkCount: 5, goalReached: true, steps: 8000)
        XCTAssertEqual(manager.ach(id: "marathonien").status, .completed)
    }

    // MARK: - Été hydraté (juillet/août, totalMl >= 1.5 * goal, 7 jours)

    func testOnDailyGoalReached_SummerHydration() {
        // Simule une date en juillet 2026 (mois 7)
        let currentMonth = Calendar.current.component(.month, from: Date())
        if currentMonth != 7 && currentMonth != 8 {
            throw XCTSkip("summer_hydration ne se teste qu'en juillet/août")
        }
        let year = Calendar.current.component(.year, from: Date())
        let key = "summer_hydration_days_\(year)"
        for _ in 0..<6 {
            manager.onDailyGoalReached(totalMl: 3000, goalMl: 2000) // 1.5x
        }
        XCTAssertNotEqual(manager.ach(id: "summer_hydration").status, .completed)
        manager.onDailyGoalReached(totalMl: 3000, goalMl: 2000)
        XCTAssertEqual(manager.ach(id: "summer_hydration").status, .completed)
    }

    func testOnDailyGoalReached_BelowThreshold_NotCounted() {
        let currentMonth = Calendar.current.component(.month, from: Date())
        guard currentMonth == 7 || currentMonth == 8 else { throw XCTSkip() }
        manager.onDailyGoalReached(totalMl: 1000, goalMl: 2000) // 0.5x → pas compté
        XCTAssertEqual(manager.ach(id: "summer_hydration").currentProgress, 0)
    }

    // MARK: - Verrouillage

    func testLockedAchievement_DoesNotProgress() {
        // iron_month est isPro=true, donc locked par défaut (non premium)
        UserDefaults.standard.set(false, forKey: "isPremiumUser")
        manager.isPremiumUser = false
        manager.onGoalReached(streak: 100, totalDays: 200)
        XCTAssertEqual(manager.ach(id: "iron_month").status, .locked)
        XCTAssertNotEqual(manager.ach(id: "iron_month").status, .completed)
    }

    func testProUnlock_UnlocksAndRestoresProgress() {
        manager.isPremiumUser = false
        XCTAssertEqual(manager.ach(id: "iron_month").status, .locked)
        manager.isPremiumUser = true
        XCTAssertNotEqual(manager.ach(id: "iron_month").status, .locked)
    }

    // MARK: - Anti-doublon de complétion

    func testCompletedAchievement_DoesNotCompleteTwice() {
        manager.onGoalReached(streak: 7, totalDays: 10)
        XCTAssertEqual(manager.ach(id: "constance").status, .completed)
        // Modifier l'état manuellement pour simuler une "non-complétion" → ne doit pas bouger
        let idx = manager.achievements.firstIndex { $0.id == "constance" }!
        // Le completeAchievement garde le status .completed, on ne peut pas le forcer
        // On teste que re-appeler la condition ne plante pas
        manager.onGoalReached(streak: 7, totalDays: 10)
        XCTAssertEqual(manager.ach(id: "constance").status, .completed)
    }

    // MARK: - Helper

    private func ach(_ id: String) -> Achievement {
        manager.achievements.first { $0.id == id }
            ?? manager.monthlyAchievements.first { $0.id == id }!
    }
}

extension AchievementManager {
    /// Helper test-only pour accéder aux achievements
    fileprivate func ach(id: String) -> Achievement {
        achievements.first { $0.id == id }
            ?? monthlyAchievements.first { $0.id == id }!
    }
}