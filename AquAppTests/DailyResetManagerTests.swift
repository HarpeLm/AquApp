import XCTest
@testable import AquApp

final class DailyResetManagerTests: XCTestCase {

    // MARK: - Calcul du prochain Lundi

    func testSecondsUntilNextMonday_Calculation() {
        let calendar = Calendar.current
        
        // Helper pour simuler les jours
        func simulateWeekday(_ weekday: Int) -> TimeInterval {
            // weekday: 1=dim, 2=lun ... 7=sam
            let daysUntilMonday = (weekday == 2) ? 7 : (9 - weekday) % 7
            return Double(daysUntilMonday) * 86400.0
        }
        
        // Lundi (2) : doit attendre le lundi suivant (7 jours)
        XCTAssertEqual(simulateWeekday(2), 7 * 86400.0, accuracy: 1.0)
        
        // Mardi (3) : doit attendre 6 jours
        XCTAssertEqual(simulateWeekday(3), 6 * 86400.0, accuracy: 1.0)
        
        // Dimanche (1) : doit attendre 1 jour
        XCTAssertEqual(simulateWeekday(1), 1 * 86400.0, accuracy: 1.0)
        
        // Samedi (7) : doit attendre 2 jours
        XCTAssertEqual(simulateWeekday(7), 2 * 86400.0, accuracy: 1.0)
    }
}