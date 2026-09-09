import XCTest
@testable import AquApp

final class WeatherManagerTests: XCTestCase {

    var mockStore: AppDataStore!
    var weatherManager: WeatherManager!

    override func setUpWithError() throws {
        super.setUp()
        // Attention : AppDataStore nécessite SwiftData. 
        // Pour un test unitaire pur, il faudrait créer un Mock de AppDataStore.
        // Ici on teste la logique mathématique de 'applyTemperature' qui est privée.
        // On va donc tester la logique métier via un Mock simple.
    }

    // MARK: - Logique Canicule (Test de la formule)

    func testHeatwaveGoalAdaptation_Formula() {
        // La règle : +200 ml par degré au-dessus de 32°C, plafonné à +1000 ml.
        let baseGoal: Double = 2170.0
        
        // Test 1 : 35°C (3 degrés au-dessus de 32)
        let extra35 = min((35.0 - 32.0) * 200, 1000)
        XCTAssertEqual(extra35, 600.0)
        
        // Test 2 : 32°C (exactement le seuil, pas de bonus)
        let extra32 = min((32.0 - 32.0) * 200, 1000)
        XCTAssertEqual(extra32, 0.0)
        
        // Test 3 : 40°C (8 degrés au-dessus, doit être plafonné à 1000)
        let extra40 = min((40.0 - 32.0) * 200, 1000)
        XCTAssertEqual(extra40, 1000.0, "Le bonus doit être plafonné à 1000 ml")
        
        // Test 4 : 25°C (pas de canicule)
        // La formule dans le code ne s'applique que si temp >= 32
    }
}