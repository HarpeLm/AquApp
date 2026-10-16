import SwiftUI
import SwiftData
import HealthKit

// MARK: - ProfileMoreMenu
// Menu « ⋯ » en haut du profil. Regroupe les actions secondaires par section ;
// pour l'instant « Confidentialité » : politique, contact (dès qu'une adresse existe)
// et « Supprimer mes données » (droit à l'effacement).

struct ProfileMoreMenu: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var xpManager: XPManager
    @EnvironmentObject var achievementManager: AchievementManager
    @EnvironmentObject var challengeManager: ChallengeManager
    @Environment(\.openURL) private var openURL

    @State private var showEraseConfirmation = false
    @State private var isErasing = false
    @State private var showPolicy = false

    var body: some View {
        Menu {
            Section(String(localized: "privacy.section.title")) {
                Button {
                    showPolicy = true
                } label: {
                    Label(String(localized: "privacy.policy"), systemImage: "doc.text")
                }

                if let contact = LegalInfo.contactURL {
                    Button {
                        openURL(contact)
                    } label: {
                        Label(String(localized: "policy.contact.email_button"), systemImage: "envelope")
                    }
                }

                Button(role: .destructive) {
                    showEraseConfirmation = true
                } label: {
                    Label(String(localized: "privacy.erase.button"), systemImage: "trash")
                }
                .accessibilityIdentifier("profile.privacy.erase")
            }
        } label: {
            Group {
                if isErasing {
                    ProgressView()
                } else {
                    Image(systemName: "ellipsis.circle")
                        .scaledFont(size: 24, weight: .regular)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .disabled(isErasing)
        .accessibilityLabel(String(localized: "profile.more_options"))
        .accessibilityIdentifier("profile.more")
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
        .sheet(isPresented: $showPolicy) {
            PrivacyPolicySheet()
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

#Preview {
    let container = try! ModelContainer(
        for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ProfileMoreMenu()
        .padding()
        .environmentObject(AppDataStore(modelContext: container.mainContext))
        .environmentObject(XPManager())
        .environmentObject(AchievementManager())
        .environmentObject(ChallengeManager())
}
