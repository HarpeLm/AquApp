import SwiftUI

// MARK: - PrivacyPolicySheet
// Politique de confidentialité dans l'app, construite à partir des clés
// `policy.<section>.title` / `policy.<section>.body` de Localizable.xcstrings.
// Dans les textes : **gras**, *italique* et [liens](url) en Markdown ;
// une ligne qui commence par « • » devient une puce.

struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Titre dans le contenu (et non en grand titre de barre) : il passe à la ligne
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "policy.title"))
                            .scaledFont(size: 30, weight: .bold)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(String(localized: "policy.updated"))
                            .scaledFont(size: 13)
                            .foregroundColor(.secondary)
                    }

                    ForEach(LegalInfo.policySections, id: \.self) { section in
                        PolicySection(
                            title: PrivacyPolicyText.title(section),
                            text: PrivacyPolicyText.body(section),
                            highlighted: section == "medical"
                        )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        if let mail = LegalInfo.contactURL {
                            Link(destination: mail) {
                                Label(String(localized: "policy.contact.email_button"), systemImage: "envelope.fill")
                            }
                        }
                        Link(destination: LegalInfo.privacyPolicyURL) {
                            Label(String(localized: "policy.online_version"), systemImage: "safari")
                        }
                    }
                    .scaledFont(size: 15, weight: .semibold)
                    .padding(.top, 4)
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(Color.app.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "policy.close")) { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("sheet.privacy_policy")
    }
}

// MARK: - Textes

enum PrivacyPolicyText {
    // Clés écrites en toutes lettres : Xcode les voit et ne les marque pas « obsolètes ».
    private static var texts: [String: (title: String, body: String)] {
        [
            "summary": (String(localized: "policy.summary.title"), String(localized: "policy.summary.body")),
            "medical": (String(localized: "policy.medical.title"), String(localized: "policy.medical.body")),
            "device": (String(localized: "policy.device.title"), String(localized: "policy.device.body")),
            "retention": (String(localized: "policy.retention.title"), String(localized: "policy.retention.body")),
            "health": (String(localized: "policy.health.title"), String(localized: "policy.health.body")),
            "offdevice": (String(localized: "policy.offdevice.title"), String(localized: "policy.offdevice.body")),
            "legal_basis": (String(localized: "policy.legal_basis.title"), String(localized: "policy.legal_basis.body")),
            "never": (String(localized: "policy.never.title"), String(localized: "policy.never.body")),
            "age": (String(localized: "policy.age.title"), String(localized: "policy.age.body")),
            "rights": (String(localized: "policy.rights.title"), String(localized: "policy.rights.body")),
            "changes": (String(localized: "policy.changes.title"), String(localized: "policy.changes.body")),
            "contact": (String(localized: "policy.contact.title"), String(localized: "policy.contact.body")),
        ]
    }

    static func title(_ section: String) -> String { texts[section]?.title ?? section }
    static func body(_ section: String) -> String { texts[section]?.body ?? "" }

    /// Markdown en ligne (gras, italique, liens) ; le texte brut si le Markdown est invalide.
    static func attributed(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

// MARK: - Section

private struct PolicySection: View {
    let title: String
    let text: String
    var highlighted = false

    private var lines: [String] {
        text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if highlighted {
                    Image(systemName: "stethoscope")
                        .foregroundColor(Color.app.primary)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .scaledFont(size: 18, weight: .bold)
            }
            .accessibilityAddTraits(.isHeader)

            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.hasPrefix("• ") {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundColor(Color.app.primary)
                            .accessibilityHidden(true)
                        Text(PrivacyPolicyText.attributed(String(line.dropFirst(2))))
                    }
                } else {
                    Text(PrivacyPolicyText.attributed(line))
                }
            }
            .scaledFont(size: 15)
            .foregroundColor(.primary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(highlighted ? 16 : 0)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(highlighted ? Color.app.primary.opacity(0.08) : Color.clear)
        )
    }
}

#Preview {
    PrivacyPolicySheet()
}
