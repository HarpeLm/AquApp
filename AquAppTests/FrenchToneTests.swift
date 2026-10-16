import XCTest
@testable import AquApp

/// L'app vouvoie l'utilisateur en français. Ce test empêche un « tu » de revenir.
/// Les phrases Siri (AppShortcuts.xcstrings) ne sont pas concernées : c'est
/// l'utilisateur qui parle à Siri (« Ajoute de l'eau dans AquApp »).
final class FrenchToneTests: XCTestCase {

    private let tutoiement = try! NSRegularExpression(
        pattern: #"(?i)(\btu\b|\bt'|\bton\b|\bta\b|\btes\b|\btoi\b|-toi\b|\bte\b)"#
    )

    private func frenchStrings() throws -> [String: String] {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "fr", ofType: "lproj"))
        let url = URL(fileURLWithPath: path).appendingPathComponent("Localizable.strings")
        return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
    }

    func testFrenchStrings_useVous() throws {
        let strings = try frenchStrings()
        XCTAssertFalse(strings.isEmpty)
        let offenders = strings.filter { _, value in
            tutoiement.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
        }
        XCTAssertTrue(offenders.isEmpty, "Tutoiement : \(offenders.keys.sorted())")
    }

    func testSiriReplies_useVous() {
        let reply = String(format: String(localized: "intent.add_water.done"), "250 ml", "1 000 ml", "2 000 ml")
        XCTAssertFalse(reply.isEmpty)
        // La réponse de Siri suit la langue de l'app ; en français, elle vouvoie.
        if Bundle.main.preferredLocalizations.first == "fr" {
            XCTAssertTrue(reply.contains("Vous en êtes"), reply)
        }
    }
}
