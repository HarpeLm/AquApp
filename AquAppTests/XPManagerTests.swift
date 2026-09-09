//
//  XPManagerTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 07/09/2026.
//


import XCTest
@testable import AquApp

// ⬇️ AJOUTE CE BLOC (helpers partagés par tous les tests XP)
enum TestKit {
    static var dayKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd"
        return f.string(from: Date())
    }
    static func resetXPDefaults() {
        let d = UserDefaults.standard
        for key in d.dictionaryRepresentation().keys where key.hasPrefix("xp_") {
            d.removeObject(forKey: key)
        }
    }
    static func setTotalXP(_ v: Int)      { UserDefaults.standard.set(v, forKey: "xp_total") }
    static func setWaterXPToday(_ v: Int) { UserDefaults.standard.set(v, forKey: "xp_water_today_\(dayKey)") }
    static let accuracy = 0.000001
}
// ⬆️ FIN DU BLOC

@MainActor
final class XPManagerTests: XCTestCase {
    // … le reste du fichier reste exactement tel quel

    var manager: XPManager!
    /// Retient tous les managers créés pendant le test :
    /// aucun dealloc en plein test → plus de crash RefCounts/SideTable.
    var retained: [XPManager] = []

    override func setUp() async throws {
        try await super.setUp()
        TestKit.resetXPDefaults()
        retained = []
        manager = XPManager()
        retained.append(manager)
    }

    override func tearDown() async throws {
        retained = []          // libère ENTRE les tests, runloop au repos
        manager = nil
        TestKit.resetXPDefaults()
        try await super.tearDown()
    }

    /// Fabrique un manager et le retient automatiquement.
    private func makeManager() -> XPManager {
        let m = XPManager()
        retained.append(m)
        return m
    }

    func testFreshState() {
        XCTAssertEqual(manager.totalXP, 0)
        XCTAssertEqual(manager.currentLevel, .goutte)
        XCTAssertNil(manager.lastGain)
        XCTAssertFalse(manager.didLevelUp)
    }

    func testAdd_DailyGoal() {
        manager.add(.dailyGoal)
        XCTAssertEqual(manager.totalXP, 10)
        XCTAssertEqual(manager.lastGain, 10)
    }

    func testAdd_NonWater_NotCapped() {
        for _ in 0..<10 { manager.add(.achievement) }
        XCTAssertEqual(manager.totalXP, 300)
    }

    func testWaterCap_StopsAt20() {
        let key = "xp_water_today_\(TestKit.dayKey)"
        let start = UserDefaults.standard.integer(forKey: key)
        for _ in 0..<6 { manager.add(.water(ml: 700)) }   // 700 ml → 4 XP → 24 tentés
        let end = UserDefaults.standard.integer(forKey: key)
        XCTAssertEqual(end, min(20, start + 24), "cap quotidien violé")
        XCTAssertEqual(manager.totalXP, end - start)
    }

    func testWaterCap_UnderCap_NotClipped() {
        let key = "xp_water_today_\(TestKit.dayKey)"
        let start = UserDefaults.standard.integer(forKey: key)
        for _ in 0..<6 { manager.add(.water(ml: 600)) }   // 600 ml → 3 XP → 18 < 20
        let end = UserDefaults.standard.integer(forKey: key)
        XCTAssertEqual(end, start + 18, "sous le cap, rien ne doit être rogné")
        XCTAssertEqual(manager.totalXP, end - start)
    }
    func testWaterCap_PartialGain() {
        TestKit.setWaterXPToday(18)
        let m = makeManager()          // ← plus de `let m` local libéré en fin de test
        m.add(.water(ml: 600))         // gain 4 → restant 2 → gain réel 2
        XCTAssertEqual(m.totalXP, 2)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "xp_water_today_\(TestKit.dayKey)"), 20)
    }

    func testWaterCap_ZeroRemaining_NoOp() {
        TestKit.setWaterXPToday(20)
        let m = makeManager()
        m.add(.water(ml: 600))
        XCTAssertEqual(m.totalXP, 0)
    }

    func testLevelUp_Detection() {
        TestKit.setTotalXP(95)
        let m = makeManager()
        m.add(.dailyGoal)
        XCTAssertEqual(m.totalXP, 105)
        XCTAssertEqual(m.currentLevel, .ruisseau)
        XCTAssertTrue(m.didLevelUp)
    }

    func testPersistence_AcrossInstances() {
        manager.add(.challenge)
        XCTAssertEqual(makeManager().totalXP, 15)
    }

    func testComputedHelpers_MidLevel() {
        TestKit.setTotalXP(350)
        let m = makeManager()
        XCTAssertEqual(m.xpInCurrentLevel, 50)
        XCTAssertEqual(m.currentLevelRange, 450)
        XCTAssertEqual(m.progressRatio, 50.0 / 450.0, accuracy: 0.000001)
        XCTAssertEqual(m.xpUntilNextLevel, 400)
    }

    func testComputedHelpers_MaxLevel() {
        TestKit.setTotalXP(15_000)
        let m = makeManager()
        XCTAssertEqual(m.currentLevel, .aquaLegend)
        XCTAssertEqual(m.currentLevelRange, 1)
        XCTAssertEqual(m.progressRatio, 1.0)
        XCTAssertNil(m.xpUntilNextLevel)
    }

    func testProgressRatio_AlwaysIn01() {
        for xp in [0, 99, 100, 999, 14_999, 15_000, 999_999] {
            TestKit.setTotalXP(xp)
            let r = makeManager().progressRatio
            XCTAssertGreaterThanOrEqual(r, 0.0)
            XCTAssertLessThanOrEqual(r, 1.0)
        }
    }
}
