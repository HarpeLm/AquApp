import Foundation

// MARK: - LegalInfo
// Source unique des informations légales.
// Le texte de la politique vit dans Localizable.xcstrings (clés `policy.<section>.title`
// et `policy.<section>.body`, en fr et en). `scripts/privacy_policy.py` en génère
// docs/PRIVACY.md et docs/PRIVACY.en.md, liés depuis App Store Connect.

enum LegalInfo {

    /// Ordre des sections de la politique (repris tel quel par scripts/privacy_policy.py).
    static let policySections: [String] = [
        "summary", "medical", "device", "retention", "health", "offdevice",
        "legal_basis", "never", "age", "rights", "changes", "contact",
    ]

    /// Adresse de contact RGPD. `nil` tant que contact@aquapp.fr n'existe pas :
    /// la politique renvoie alors vers GitHub Issues.
    static let contactEmail: String? = nil

    private static let docsBase = "https://github.com/HarpeLm/AquApp/blob/main/docs/"

    /// Version en ligne de la politique, dans la langue de l'app.
    static var privacyPolicyURL: URL {
        // Langue réellement affichée par l'app (et non celle de l'appareil)
        let french = Bundle.main.preferredLocalizations.first == "fr"
        return URL(string: docsBase + (french ? "PRIVACY.md" : "PRIVACY.en.md"))!
    }

    static var contactURL: URL? {
        contactEmail.flatMap { URL(string: "mailto:\($0)") }
    }
}
