import SwiftUI

struct ProfileHydrationView: View {
    let dailyGoalMl: Double
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                title:    String(localized: "profile.section.hydration"),
                sfSymbol: "drop.fill",
                color:    Color(hex: "4DA8F5")
            )

            Button(action: onTap) {
                HStack {
                    Image(systemName: "target")
                        .foregroundColor(Color(hex: "4DA8F5"))
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    Text(L10n.profileDailyGoal)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(UnitFormatter.volume(dailyGoalMl))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.systemGray3))
                        .accessibilityHidden(true)
                }
                .padding(16)
                .background(Color("AppCardBackground"))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
            .accessibilityLabel(L10n.profileDailyGoal)
            .accessibilityValue(String(format: String(localized: "water.ml_value"), Int(dailyGoalMl)))
            .accessibilityHint(String(localized: "profile.goal.accessibility_hint"))
        }
        .padding(.horizontal)
    }
}

#Preview {
    ProfileHydrationView(dailyGoalMl: 2170, onTap: {})
        .padding(.vertical)
        .background(Color("AppBackground"))
}
