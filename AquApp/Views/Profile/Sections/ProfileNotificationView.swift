import SwiftUI

struct ProfileNotificationView: View {
    @Binding var notificationsOn: Bool
    @State private var showSettings = false

    @AppStorage("notifStartHour")    private var startHour: Int    = 8
    @AppStorage("notifEndHour")      private var endHour: Int      = 22
    @AppStorage("notifIntervalHour") private var intervalHour: Int = 2

    var subtitle: String {
        guard notificationsOn else { return String(localized: "notif.disabled") }
        return "\(startHour)h–\(endHour)h · \(String(format: String(localized: "notif.every_n_hours"), intervalHour))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                title:    String(localized: "profile.section.notifications"),
                sfSymbol: "bell.fill",
                color:    .orange
            )

            Button { showSettings = true } label: {
                HStack {
                    Image(systemName: notificationsOn ? "bell.badge.fill" : "bell.slash.fill")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.profileNotifications)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
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
            .accessibilityLabel(L10n.profileNotifications)
            .accessibilityValue(subtitle)
            .accessibilityHint(String(localized: "profile.notif.accessibility_hint"))
        }
        .padding(.horizontal)
        .sheet(isPresented: $showSettings) {
            NotificationSettingsSheet(
                notificationsOn: $notificationsOn,
                isPresented:     $showSettings
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(24)
        }
    }
}

#Preview {
    ProfileNotificationView(notificationsOn: .constant(true))
        .padding(.vertical)
        .background(Color("AppBackground"))
}
