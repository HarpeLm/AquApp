import SwiftUI
import SwiftData

// MARK: - ProfileStatsView

struct ProfileStatsView: View {
    @EnvironmentObject var store: AppDataStore

    let completedAchievements: Int
    let completedChallenges: Int

    var totalCompleted: Int { completedAchievements + completedChallenges }

    var body: some View {
        HStack(spacing: 0) {

            StatCell(
                value:  "\(store.currentStreak)",
                label:  String(localized: "profile.stats.streak"),
                color:  .orange,
                symbol: "flame.fill"
            )

            Divider().frame(height: 40)

            StatCell(
                value:  "\(totalCompleted)",
                label:  String(localized: "profile.stats.achievements"),
                color:  Color(hex: "4DA8F5"),
                symbol: "star.fill"
            )

            Divider().frame(height: 40)

            StatCell(
                value:  String(format: "%.1f L", store.totalWaterLiters),
                label:  String(localized: "profile.stats.total_water"),
                color:  Color(hex: "10B981"),
                symbol: "drop.fill"
            )
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(Color("AppCardBackground"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - StatCell

private struct StatCell: View {
    let value:  String
    let label:  String
    let color:  Color
    let symbol: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

#Preview {
    let config    = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
        configurations: config
    )
    let store = AppDataStore(modelContext: container.mainContext)
    ProfileStatsView(completedAchievements: 3, completedChallenges: 2)
        .environmentObject(store)
        .padding(.vertical)
        .background(Color("AppBackground"))
}
