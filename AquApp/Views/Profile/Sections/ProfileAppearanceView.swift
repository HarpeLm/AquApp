import SwiftUI

struct ProfileAppearanceView: View {
    @Binding var colorSchemeRaw: String
    @EnvironmentObject var storeKit:     StoreKitManager
    @EnvironmentObject var appIconManager: AppIconManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Icône de l'app (style Snapchat) ───────────────────────
            AppIconPickerView()
                .environmentObject(storeKit)
                .environmentObject(appIconManager)

            // ── Thème clair / sombre / système ────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(
                    title:    String(localized: "profile.section.appearance"),
                    sfSymbol: "paintbrush.fill",
                    color:    .purple
                )

                HStack {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundColor(.purple)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    Text(String(localized: "profile.theme"))
                        .font(.system(size: 15))
                    Spacer()
                    Picker("", selection: $colorSchemeRaw) {
                        Text(String(localized: "profile.system")).tag("system")
                        Text(String(localized: "profile.light")).tag("light")
                        Text(String(localized: "profile.dark")).tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                .padding(16)
                .background(Color("AppCardBackground"))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    ProfileAppearanceView(colorSchemeRaw: .constant("system"))
        .environmentObject(StoreKitManager())
        .environmentObject(AppIconManager())
        .padding(.vertical)
        .background(Color("AppBackground"))
}
