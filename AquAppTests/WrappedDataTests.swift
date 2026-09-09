//
//  WrappedDataTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 07/09/2026.
//


import XCTest
@testable import AquApp

final class WrappedDataTests: XCTestCase {

    private func make(
        goalDays: Int = 0, bestStreak: Int = 0, soberDays: Int = 0,
        xpTotal: Int = 0, userName: String = "Fab"
    ) -> WrappedData {
        WrappedData(
            year: 2025, userName: userName,
            totalLiters: 0, totalGlasses: 0, avgDailyMl: 0,
            bestMonthName: "—", bestMonthLiters: 0,
            goalDays: goalDays, bestStreak: bestStreak, soberDays: soberDays,
            alcoholLiters: 0, topAlcoholKind: "—",
            morningDays: 0, heatwaveDays: 0,
            xpTotal: xpTotal, xpLevelName: "", achievementsCount: 0, challengesCount: 0,
            monthlyTotals: Array(repeating: 0, count: 12),
            monthLabels: Array(repeating: "J", count: 12)
        )
    }

    // MARK: - Percentile (bornes exactes : 347/329/292/256/183)

    func testPercentileTop_Boundaries() {
        let table: [(Int, Int)] = [
            (365, 1), (347, 1), (346, 5), (329, 5), (328, 10),
            (292, 10), (291, 20), (256, 20), (255, 35), (183, 35), (182, 50), (0, 50),
        ]
        for (goalDays, expected) in table {
            XCTAssertEqual(make(goalDays: goalDays).percentileTop, expected, "goalDays=\(goalDays)")
        }
    }

    // MARK: - Légendaire (4 déclencheurs + bornes)

    func testIsLegendary_Boundaries() {
        XCTAssertFalse(make().isLegendary)
        XCTAssertTrue(make(bestStreak: 100).isLegendary)
        XCTAssertFalse(make(bestStreak: 99).isLegendary)
        XCTAssertTrue(make(soberDays: 300).isLegendary)
        XCTAssertFalse(make(soberDays: 299).isLegendary)
        XCTAssertTrue(make(xpTotal: 8500).isLegendary)
        XCTAssertFalse(make(xpTotal: 8499).isLegendary)
        XCTAssertTrue(make(goalDays: 347).isLegendary)   // percentile top 1
        XCTAssertFalse(make(goalDays: 346).isLegendary)
    }

    func testLegendaryReason_PriorityOrder() {
        // streak > sobriété > percentile > xp
        let both = make(bestStreak: 100, soberDays: 300)
        XCTAssertEqual(both.legendaryReason,
                       String(format: String(localized: "wrapped.legendary.reason_streak"), 100))
        let sober = make(soberDays: 300, xpTotal: 9000)
        XCTAssertEqual(sober.legendaryReason,
                       String(format: String(localized: "wrapped.legendary.reason_sober"), 300))
        let xp = make(xpTotal: 9000)
        XCTAssertEqual(xp.legendaryReason,
                       String(format: String(localized: "wrapped.legendary.reason_xp"), 9000))
    }

    // MARK: - Message de clôture (priorités + bornes)

    func testAdaptiveClosingMessage_Priority() {
        // santé (sober ≥ 292) > discipline (streak ≥ 30) > équilibre (goal ≥ 219) > défaut
        XCTAssertEqual(make(soberDays: 292, bestStreak: 50).adaptiveClosingMessage,
                       String(format: String(localized: "wrapped.closing.health"), "Fab"))
        XCTAssertEqual(make(soberDays: 291, bestStreak: 30).adaptiveClosingMessage,
                       String(format: String(localized: "wrapped.closing.discipline"), "Fab"))
        XCTAssertEqual(make(soberDays: 291, bestStreak: 29, goalDays: 219).adaptiveClosingMessage,
                       String(format: String(localized: "wrapped.closing.balance"), "Fab"))
        XCTAssertEqual(make(soberDays: 291, bestStreak: 29, goalDays: 218).adaptiveClosingMessage,
                       String(format: String(localized: "wrapped.closing.default"), "Fab"))
    }

    // MARK: - Codable round-trip

    func testCodable_RoundTrip() throws {
        let original = make(goalDays: 42, bestStreak: 7, soberDays: 100, xpTotal: 500)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WrappedData.self, from: data)
        XCTAssertEqual(decoded.year, original.year)
        XCTAssertEqual(decoded.userName, original.userName)
        XCTAssertEqual(decoded.goalDays, original.goalDays)
        XCTAssertEqual(decoded.bestStreak, original.bestStreak)
        XCTAssertEqual(decoded.soberDays, original.soberDays)
        XCTAssertEqual(decoded.xpTotal, original.xpTotal)
        XCTAssertEqual(decoded.monthlyTotals, original.monthlyTotals)
        XCTAssertEqual(decoded.monthLabels, original.monthLabels)
    }
}