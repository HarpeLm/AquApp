import XCTest
@testable import AquApp

final class XPManagerTests: XCTestCase {

    var xpManager: XPManager!

    override func setUpWithError() throws {
        super.setUp()
        // On utilise une instance fraîche
        xpManager = XPManager()
    }

    override func tearDownWithError() throws {
        // Nettoyage du UserDefaults pour éviter les conflits entre les tests
        let defaults = UserDefaults.standard
        let dict = defaults.dictionaryRepresentation()
        for key in dict.keys {
            if key.hasPrefix("xp_") {
                defaults.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    // MARK: - Niveaux et Seuils

    func testLevelThresholdsProgression() {
        // Les seuils doivent être croissants
        var previousThreshold = 0
        for level in XPLevel.allCases {
            XCTAssertGreaterThanOrEqual(level.threshold, previousThreshold, "Le seuil de \(level) doit être supérieur ou égal au précédent")
            previousThreshold = level.threshold
        }
    }

    func testLevelForXP_ReturnsCorrectLevel() {
        XCTAssertEqual(XPLevel.level(for: 0), .goutte)
        XCTAssertEqual(XPLevel.level(for: 99), .goutte)
        XCTAssertEqual(XPLevel.level(for: 100), .ruisseau)
        XCTAssertEqual(XPLevel.level(for: 350), .source)
        XCTAssertEqual(XPLevel.level(for: 15000), .aquaLegend)
        XCTAssertEqual(XPLevel.level(for: 999999), .aquaLegend)
    }

    func testNextLevel_ReturnsNilForMaxLevel() {
        XCTAssertNil(XPLevel.aquaLegend.next, "Le niveau max ne doit pas avoir de 'next'")
    }

    // MARK: - Gains de XP

    func testXPSources_Amounts() {
        XCTAssertEqual(XPSource.water(ml: 100).amount, 1)
        XCTAssertEqual(XPSource.water(ml: 250).amount, 2)
        XCTAssertEqual(XPSource.water(ml: 450).amount, 3)
        XCTAssertEqual(XPSource.water(ml: 600).amount, 4)
        XCTAssertEqual(XPSource.dailyGoal.amount, 10)
        XCTAssertEqual(XPSource.challenge.amount, 15)
        XCTAssertEqual(XPSource.achievement.amount, 30)
        XCTAssertEqual(XPSource.streak7.amount, 20)
    }

    // MARK: - Plafonnement quotidien de l'eau

    func testWaterXPCap_PreventsFarming() {
        let expectation = XCTestExpectation(description: "Ajout de XP")
        
        // Le plafond est de 20 XP d'eau par jour.
        // Ajouter 10 verres de 600ml (4 XP chacun) devrait rapporter 20 XP et s'arrêter là.
        
        Task { @MainActor in
            // 1. Vider les XP du jour
            let defaults = UserDefaults.standard
            let todayKey = "xp_water_today_\(dateKey())"
            defaults.set(0, forKey: todayKey)
            
            // 2. Ajouter 10 fois 4 XP (devrait plafonner à 20)
            for _ in 0..<10 {
                xpManager.add(.water(ml: 600))
            }
            
            // Vérification
            let totalWaterXP = defaults.integer(forKey: todayKey)
            XCTAssertEqual(totalWaterXP, 20, "Les XP d'eau doivent être plafonnés à 20 par jour")
            
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }
    
    private func dateKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd"
        return f.string(from: Date())
    }
}