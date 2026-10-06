import XCTest
@testable import AquApp

/// Un utilisateur américain voit des fl oz : aucun texte ne doit afficher « ml » en dur
/// à côté d'une valeur calculée, sinon l'écran mélange les deux unités.
final class VolumeUnitTests: XCTestCase {

    private let volumeKeys = [
        "accessibility.chart_bar_value", "activity.water_entry", "alcohol.added_feedback",
        "alcohol.compensation_label", "body.goal_ml_per_day", "challenge.cadence_parfaite.desc",
        "challenge.card.subtitle", "challenge.flash_hydrate.desc", "challenge.flash.progress",
        "challenge.matin.progress", "challenge.matinal.desc", "challenge.progress_ml",
        "challenge.recuperation.desc", "challenge.recuperation.progress", "challenge.grand_buveur.desc",
        "progress.alcohol_compensation", "progress.goal_label", "stats.avg_per_day",
        "intent.add_water.done", "intent.add_alcohol.done", "intent.today.result", "intent.today.goal_reached",
    ]

    private func value(_ key: String, language: String) throws -> String {
        let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path)).localizedString(forKey: key, value: nil, table: nil)
    }

    func testVolumeStrings_neverHardcodeTheUnit() throws {
        for language in ["fr", "en"] {
            for key in volumeKeys {
                let text = try value(key, language: language)
                XCTAssertNotEqual(text, key, "\(key) manquante en \(language)")
                XCTAssertNil(text.range(of: #"\b(ml|mL|L)\b"#, options: .regularExpression),
                             "\(key) (\(language)) écrit l'unité en dur : « \(text) »")
            }
        }
    }

    func testVolumeToMl_isTheInverseOfTheDisplayedUnit() throws {
        // Ce que l'utilisateur tape est dans l'unité affichée (ml, ou fl oz aux États-Unis).
        let typed = try XCTUnwrap(UnitFormatter.volumeToMl("12"))
        let shownBack = UnitFormatter.volumeNumber(typed)
        XCTAssertEqual(shownBack, "12")
        XCTAssertEqual(UnitFormatter.volumeToMl("12,5"), UnitFormatter.volumeToMl("12.5"))
        XCTAssertNil(UnitFormatter.volumeToMl("abc"))
    }
}
