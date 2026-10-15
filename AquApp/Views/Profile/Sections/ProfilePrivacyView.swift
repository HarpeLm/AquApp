import SwiftUI
import SwiftData
import HealthKit

// MARK: - ProfilePrivacyView
// Section « Confidentialité » du profil : politique de confidentialité et
// « Supprimer mes données » (droit à l'effacement).

struct ProfilePrivacyView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var xpManager: XPManager
    @EnvironmentObject var achievementManager: AchievementManager
    @EnvironmentObject var challengeManager: ChallengeManager

    @State private var showEraseConfirmation = false
    @State private var isErasing = false

    static let privacyPolicyURL = URL(string: "https://github.com/HarpeLm/AquApp/blob/main/docs/PRIVACY.md")!

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                title:    String(localized: "privacy.section.title"),
                sfSymbol: "hand.raised.fill",
                color:    Color.app.primary
            )

            VStack(spacing: 0) {
                Link(destination: Self.privacyPolicyURL) {
                    PrivacyRow(
                        sfSymbol: "doc.text.fill",
                        color:    Color.app.primary,
                        title:    String(localized: "privacy.policy"),
                        trailing: "arrow.up.right"
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 52)

                Button {
                    showEraseConfirmation = true
                } label: {
                    PrivacyRow(
                        sfSymbol: "trash.fill",
                        color:    .red,
                        title:    String(localized: "privacy.erase.button"),
                        subtitle: String(localized: "privacy.erase.subtitle"),
                        isDestructive: true,
                        isBusy:   isErasing
                    )
                }
                .buttonStyle(.plain)
                .disabled(isErasing)
                .accessibilityIdentifier("profile.privacy.erase")
            }
            .background(Color.app.card)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal)
        .confirmationDialog(
            String(localized: "privacy.erase.confirm.title"),
            isPresented: $showEraseConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "privacy.erase.confirm.app_only"), role: .destructive) {
                erase(includeHealthData: false)
            }
            if HKHealthStore.isHealthDataAvailable() {
                Button(String(localized: "privacy.erase.confirm.with_health"), role: .destructive) {
                    erase(includeHealthData: true)
                }
            }
            Button(String(localized: "privacy.erase.confirm.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "privacy.erase.confirm.message"))
        }
    }

    private func erase(includeHealthData: Bool) {
        isErasing = true
        Task {
            await DataEraser.eraseAll(
                store: store,
                xpManager: xpManager,
                achievementManager: achievementManager,
                challengeManager: challengeManager,
                options: .init(includeHealthData: includeHealthData)
            )
            HapticManager.shared.entryDeleted()
            isErasing = false
        }
    }
}

// MARK: - Ligne

private struct PrivacyRow: View {
    let sfSymbol: String
    let color: Color
    let title: String
    var subtitle: String? = nil
    var trailing: String = "chevron.right"
    var isDestructive = false
    var isBusy = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: sfSymbol)
                    .scaledFont(size: 14, weight: .medium)
                    .foregroundColor(color)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .scaledFont(size: 15, weight: isDestructive ? .semibold : .regular)
                    .foregroundColor(isDestructive ? .red : .primary)
                if let subtitle {
                    Text(subtitle)
                        .scaledFont(size: 12)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if isBusy {
                ProgressView()
            } else {
                Image(systemName: trailing)
                    .scaledFont(size: 12)
                    .foregroundColor(Color(UIColor.systemGray3))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

#Preview {
    let container = try! ModelContainer(
        for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ProfilePrivacyView()
        .padding(.vertical)
        .background(Color.app.background)
        .environmentObject(AppDataStore(modelContext: container.mainContext))
        .environmentObject(XPManager())
        .environmentObject(AchievementManager())
        .environmentObject(ChallengeManager())
}
