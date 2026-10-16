import XCTest
@testable import AquApp

/// Politique de confidentialité et avertissement santé : chaque section existe
/// en français et en anglais, et s'affiche correctement dans l'app.
final class PrivacyPolicyTests: XCTestCase {

    private let languages = ["fr", "en"]

    private func bundle(_ language: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }

    private func string(_ key: String, _ language: String) throws -> String {
        try bundle(language).localizedString(forKey: key, value: nil, table: "Localizable")
    }

    private var policyKeys: [String] {
        LegalInfo.policySections.flatMap { ["policy.\($0).title", "policy.\($0).body"] }
            + ["policy.title", "policy.updated"]
    }

    // MARK: - Traductions

    func testEverySection_isTranslatedInFrenchAndEnglish() throws {
        for key in policyKeys {
            let fr = try string(key, "fr")
            let en = try string(key, "en")
            XCTAssertNotEqual(fr, key, "\(key) manquant en français")
            XCTAssertNotEqual(en, key, "\(key) missing in English")
            XCTAssertNotEqual(fr, en, "\(key) : l'anglais semble non traduit")
        }
    }

    func testInterfaceStrings_areTranslated() throws {
        for key in ["policy.contact.email_button", "policy.online_version", "policy.close",
                    "medical.disclaimer.short", "privacy.medical_notice"] {
            for language in languages {
                XCTAssertNotEqual(try string(key, language), key, "\(key) manquant en \(language)")
            }
        }
    }

    func testSections_haveNoDuplicates() {
        XCTAssertEqual(Set(LegalInfo.policySections).count, LegalInfo.policySections.count)
    }

    // MARK: - Affichage dans l'app

    func testSheetTable_coversEverySection() {
        for section in LegalInfo.policySections {
            XCTAssertNotEqual(PrivacyPolicyText.title(section), section, "titre de « \(section) » absent de PrivacyPolicySheet")
            XCTAssertFalse(PrivacyPolicyText.body(section).isEmpty, "texte de « \(section) » absent de PrivacyPolicySheet")
        }
    }

    func testMarkdown_isValidInBothLanguages() throws {
        for section in LegalInfo.policySections {
            for language in languages {
                let body = try string("policy.\(section).body", language)
                for line in body.split(separator: "\n") {
                    XCTAssertNoThrow(
                        try AttributedString(markdown: String(line),
                                             options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)),
                        "\(section) (\(language)) : « \(line) »"
                    )
                }
                XCTAssertFalse(body.contains("**") && body.components(separatedBy: "**").count % 2 == 0,
                               "\(section) (\(language)) : gras non refermé")
            }
        }
    }

    func testAttributed_rendersBoldWithoutAsterisks() {
        let rendered = String(PrivacyPolicyText.attributed("**AquApp** ne vend rien").characters)
        XCTAssertEqual(rendered, "AquApp ne vend rien")
    }

    func testLinks_areClickable() throws {
        for language in languages {
            let rights = PrivacyPolicyText.attributed(try string("policy.rights.body", language))
            XCTAssertTrue(rights.runs.contains { $0.link?.host?.contains("cnil.fr") == true },
                          "lien CNIL absent (\(language))")
            let contact = PrivacyPolicyText.attributed(try string("policy.contact.body", language))
            XCTAssertTrue(contact.runs.contains { $0.link != nil }, "lien de contact absent (\(language))")
        }
    }

    // MARK: - Contenu exigé (RGPD, App Store)

    func testPolicy_coversWhatGDPRRequires() throws {
        let fr = try LegalInfo.policySections
            .map { try string("policy.\($0).body", "fr") }
            .joined(separator: "\n")
        XCTAssertTrue(fr.contains("CNIL"), "droit de réclamation auprès de la CNIL")
        XCTAssertTrue(fr.contains("consentement"), "base légale : consentement")
        XCTAssertTrue(fr.contains("art. 9.2.a"), "base légale des données de santé")
        XCTAssertTrue(fr.contains("15 ans"), "âge minimum")
        XCTAssertTrue(fr.contains("Fabian Dargaud"), "responsable du traitement")
        XCTAssertTrue(fr.contains("WeatherKit"), "destinataire de la position")
        XCTAssertTrue(fr.contains("Supprimer mes données"), "moyen d'exercer le droit à l'effacement")
    }

    func testMedicalNotice_saysItIsNotMedicalAdvice() throws {
        XCTAssertTrue(try string("policy.medical.body", "fr").contains("avis médical"))
        XCTAssertTrue(try string("policy.medical.body", "en").contains("medical advice"))
        XCTAssertTrue(try string("medical.disclaimer.short", "fr").contains("professionnel de santé"))
        XCTAssertTrue(try string("medical.disclaimer.short", "en").contains("health professional"))
    }

    // MARK: - Liens

    func testOnlinePolicy_pointsToTheRepository() {
        let url = LegalInfo.privacyPolicyURL
        XCTAssertEqual(url.host, "github.com")
        XCTAssertTrue(url.path.hasSuffix("PRIVACY.md") || url.path.hasSuffix("PRIVACY.en.md"))
    }

    func testContactURL_followsContactEmail() {
        if let email = LegalInfo.contactEmail {
            XCTAssertEqual(LegalInfo.contactURL?.absoluteString, "mailto:\(email)")
        } else {
            XCTAssertNil(LegalInfo.contactURL)
        }
    }
}
