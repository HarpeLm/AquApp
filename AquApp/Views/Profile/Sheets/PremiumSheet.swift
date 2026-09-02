import SwiftUI
import StoreKit
import UserNotifications

// MARK: - PremiumSheet
//
// VERSION LANCEMENT — aucun achat possible.
// Le bloc CTA est remplacé par un encart "Bientôt disponible" avec un bouton
// "Me prévenir à la sortie" qui :
//   1. Demande l'autorisation de notifications iOS (UNUserNotificationCenter)
//   2. Stocke le consentement dans UserDefaults ("premium_notify_requested")
//
// Pour réactiver le vrai StoreKit quand le Premium est prêt :
//   → Remplacer LaunchCTASection par le CTA d'achat original
//   → Les utilisateurs ayant "premium_notify_requested" = true recevront
//     la notification locale programmée au prochain lancement.

struct PremiumSheet: View {
    @Binding var isPremiumUser: Bool
    @Binding var isPresented:   Bool

    @EnvironmentObject var storeKit: StoreKitManager

    var features: [(sfSymbol: String, color: Color, title: String, subtitle: String)] {
        L10n.premiumFeatures.map { f in
            (sfSymbol: f.symbol, color: colorForSymbol(f.symbol), title: f.title, subtitle: f.subtitle)
        }
    }

    private func colorForSymbol(_ symbol: String) -> Color {
        switch symbol {
        case "medal.fill":              return .yellow
        case "chart.bar.fill":          return Color(hex: "4DA8F5")
        case "clock.fill":              return Color(hex: "10B981")
        case "paintbrush.fill":         return .purple
        case "bell.badge.fill":         return .orange
        case "widget.small.badge.plus": return .indigo
        case "app.badge":               return Color(hex: "4DA8F5")
        default:                        return Color(hex: "4DA8F5")
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(UIColor.systemGray4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // Bouton fermer
            HStack {
                Spacer()
                Button { isPresented = false } label: {
                    ZStack {
                        Circle().fill(Color(UIColor.systemGray5)).frame(width: 32, height: 32)
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(String(localized: "goal.editor.close"))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 20) {

                    // MARK: Hero
                    VStack(spacing: 10) {
                        ZStack {
                            Circle().fill(Color.orange.opacity(0.15)).frame(width: 80, height: 80)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.orange)
                                .accessibilityHidden(true)
                        }
                        Text(String(localized: "premium.title"))
                            .font(.system(size: 26, weight: .bold))
                        Text(String(localized: "premium.subtitle"))
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // MARK: Features
                    VStack(spacing: 0) {
                        ForEach(features.indices, id: \.self) { i in
                            let f = features[i]
                            FeatureRow(
                                sfSymbol: f.sfSymbol,
                                color:    f.color,
                                title:    f.title,
                                subtitle: f.subtitle
                            )
                            if i < features.count - 1 {
                                Divider().padding(.leading, 70)
                            }
                        }
                        Divider().padding(.leading, 70)
                        FeatureRow(
                            sfSymbol: "app.badge",
                            color:    Color(hex: "4DA8F5"),
                            title:    String(localized: "premium.feature_icon.title"),
                            subtitle: String(localized: "premium.feature_icon.subtitle")
                        )
                    }
                    .background(Color("AppCardBackground"))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)

                    // MARK: Aperçu icônes Premium
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "premium.icons_preview_title"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(AppIcon.allCases.filter { $0.isPremium }) { icon in
                                    VStack(spacing: 6) {
                                        Group {
                                            if UIImage(named: icon.previewAssetName) != nil {
                                                Image(icon.previewAssetName)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 64, height: 64)
                                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                            } else {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .fill(LinearGradient(
                                                            colors: icon.backgroundColors,
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ))
                                                    AppDropInline(icon: icon)
                                                        .frame(width: 26, height: 32)
                                                }
                                                .frame(width: 64, height: 64)
                                            }
                                        }
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color(UIColor.systemGray5), lineWidth: 1)
                                        )
                                        .accessibilityLabel(icon.localizedName)
                                        Text(icon.localizedName)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    .accessibilityElement(children: .combine)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                        }
                        .accessibilityLabel(String(localized: "premium.icons_preview_title"))
                    }

                    // MARK: Bloc lancement — remplace le CTA d'achat
                    LaunchCTASection(isPresented: $isPresented)

                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .background(Color("AppBackground"))
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - LaunchCTASection

private struct LaunchCTASection: View {
    @Binding var isPresented: Bool

    private let notifyKey = "premium_notify_requested"

    @State private var notifyState: NotifyState = .idle
    @State private var showPermissionDeniedAlert = false

    enum NotifyState { case idle, loading, registered, denied }

    private var alreadyRegistered: Bool {
        UserDefaults.standard.bool(forKey: notifyKey)
    }

    var body: some View {
        VStack(spacing: 0) {

            // Encart principal
            VStack(spacing: 16) {

                // Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "4DA8F5").opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "sparkles")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "4DA8F5"))
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(String(localized: "premium.launch.free_title"))
                                .font(.system(size: 15, weight: .bold))
                            Text(String(localized: "premium.launch.beta_badge"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "4DA8F5"))
                                .cornerRadius(5)
                                .accessibilityHidden(true)
                        }
                        Text(String(localized: "premium.launch.coming_soon"))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .accessibilityElement(children: .combine)

                Divider()

                // Message
                Text(String(localized: "premium.launch.message"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Bouton "Me prévenir"
                Button { handleNotifyTap() } label: {
                    HStack(spacing: 8) {
                        switch notifyState {
                        case .loading:
                            ProgressView().tint(.white)
                            Text(String(localized: "premium.launch.notify_loading"))
                                .font(.system(size: 15, weight: .semibold))
                        case .registered:
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 16))
                                .accessibilityHidden(true)
                            Text(String(localized: "premium.launch.notify_registered"))
                                .font(.system(size: 15, weight: .semibold))
                        case .denied:
                            Image(systemName: "bell.slash.fill").font(.system(size: 16))
                                .accessibilityHidden(true)
                            Text(String(localized: "premium.launch.notify_denied"))
                                .font(.system(size: 15, weight: .semibold))
                        case .idle:
                            Image(systemName: alreadyRegistered
                                  ? "checkmark.circle.fill"
                                  : "bell.fill")
                                .font(.system(size: 16))
                                .accessibilityHidden(true)
                            Text(alreadyRegistered
                                 ? String(localized: "premium.launch.notify_already")
                                 : String(localized: "premium.launch.notify_cta"))
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Group {
                            if notifyState == .registered || alreadyRegistered {
                                Color(hex: "10B981")
                            } else if notifyState == .denied {
                                Color.secondary
                            } else {
                                Color(hex: "4DA8F5")
                            }
                        }
                    )
                    .cornerRadius(14)
                    .animation(.easeInOut(duration: 0.2), value: notifyState)
                }
                .accessibilityLabel({
                    switch notifyState {
                    case .loading:    return String(localized: "premium.launch.a11y.label.loading")
                    case .registered: return String(localized: "premium.launch.a11y.label.registered")
                    case .denied:     return String(localized: "premium.launch.a11y.label.denied")
                    case .idle:       return alreadyRegistered
                                           ? String(localized: "premium.launch.notify_already")
                                           : String(localized: "premium.launch.a11y.label.idle")
                    }
                }())
                .accessibilityValue({
                    switch notifyState {
                    case .loading:    return String(localized: "premium.launch.a11y.value.loading")
                    case .registered: return String(localized: "premium.launch.a11y.value.registered")
                    case .denied:     return String(localized: "premium.launch.a11y.value.denied")
                    case .idle:       return alreadyRegistered
                                           ? String(localized: "premium.launch.a11y.value.already")
                                           : ""
                    }
                }())
                .disabled(
                    notifyState == .loading ||
                    notifyState == .registered ||
                    alreadyRegistered
                )
            }
            .padding(18)
            .background(Color("AppCardBackground"))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(hex: "4DA8F5").opacity(0.2), lineWidth: 1.5)
            )
            .shadow(color: Color(hex: "4DA8F5").opacity(0.07), radius: 12, x: 0, y: 4)

            // Fermer
            Button { isPresented = false } label: {
                Text(String(localized: "premium.launch.dismiss"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel(String(localized: "premium.launch.dismiss"))
            .padding(.top, 14)
        }
        .onAppear {
            if alreadyRegistered { notifyState = .registered }
        }
        .alert(String(localized: "premium.launch.alert.title"), isPresented: $showPermissionDeniedAlert) {
            Button(String(localized: "premium.launch.alert.open_settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(String(localized: "premium.launch.alert.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "premium.launch.alert.message"))
        }
    }

    // MARK: - Logique

    private func handleNotifyTap() {
        notifyState = .loading

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {

                case .authorized, .provisional, .ephemeral:
                    registerNotifyIntent()

                case .notDetermined:
                    UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                            DispatchQueue.main.async {
                                granted ? registerNotifyIntent() : (notifyState = .denied)
                            }
                        }

                case .denied:
                    notifyState = .denied
                    showPermissionDeniedAlert = true

                @unknown default:
                    notifyState = .idle
                }
            }
        }
    }

    /// Persiste le consentement + envoie une confirmation immédiate à l'utilisateur.
    private func registerNotifyIntent() {
        UserDefaults.standard.set(true, forKey: notifyKey)
        notifyState = .registered

        let content   = UNMutableNotificationContent()
        content.title = String(localized: "premium.launch.notif.title")
        content.body  = String(localized: "premium.launch.notif.body")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "aquapp_premium_notify_confirm",
            content:    content,
            trigger:    trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - FeatureRow

private struct FeatureRow: View {
    let sfSymbol: String
    let color:    Color
    let title:    String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: sfSymbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(subtitle).font(.system(size: 12)).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(hex: "10B981"))
                .font(.system(size: 18))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - AppDropInline

private struct AppDropInline: View {
    let icon: AppIcon
    var body: some View {
        if icon.dropFilled {
            DropPathShape().fill(Color.white.opacity(0.92))
        } else {
            DropPathShape().stroke(icon.dropStrokeColor, lineWidth: 3)
        }
    }
}

// MARK: - Preview

#Preview {
    PremiumSheet(isPremiumUser: .constant(false), isPresented: .constant(true))
        .environmentObject(StoreKitManager())
}
