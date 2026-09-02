import UIKit
import SwiftUI
import Combine

// MARK: - AppIcon

enum AppIcon: String, CaseIterable, Identifiable {
    case ocean       = "Ocean"
    case minuit      = "Minuit"
    case givre       = "Givre"
    case lagon       = "Lagon"
    case aurora      = "Aurora"
    case cristal     = "Cristal"
    case saphir      = "Saphir"
    case nuitEtoilee = "NuitEtoilee"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .ocean:       return String(localized: "app_icon.ocean")
        case .minuit:      return String(localized: "app_icon.minuit")
        case .givre:       return String(localized: "app_icon.givre")
        case .lagon:       return String(localized: "app_icon.lagon")
        case .aurora:      return String(localized: "app_icon.aurora")
        case .cristal:     return String(localized: "app_icon.cristal")
        case .saphir:      return String(localized: "app_icon.saphir")
        case .nuitEtoilee: return String(localized: "app_icon.nuit_etoilee")
        }
    }

    /// Nom de l'icône alternative passé à setAlternateIconName.
    /// nil pour l'icône principale (Ocean).
    var alternateIconName: String? { self == .ocean ? nil : rawValue }

    var isPremium: Bool { self != .ocean }

    // MARK: - Nom de l'asset de prévisualisation
    //
    // iOS ne permet PAS de lire les icônes alternatives via UIImage(named:).
    // Solution : ajouter dans Assets.xcassets un Image Set nommé
    // "preview_Ocean", "preview_Minuit", etc. contenant la même image
    // 1024×1024 que l'icône correspondante.
    //
    // Étapes dans Xcode :
    //   1. Clic droit sur Assets.xcassets > New Image Set
    //   2. Nommer : preview_Ocean (preview_Minuit, preview_Givre…)
    //   3. Glisser l'image 1024×1024 de l'icône dans le slot "Universal"
    //   4. Répéter pour chaque icône
    //
    var previewAssetName: String {
        "preview_\(rawValue)"
    }

    var backgroundColors: [Color] {
        switch self {
        case .ocean:       return [Color(hex: "72C8FF"), Color(hex: "1A6FDB")]
        case .minuit:      return [Color(hex: "0C0C1E"), Color(hex: "0D1A3A")]
        case .givre:       return [Color(hex: "EAF4FF"), Color(hex: "C8E2F5")]
        case .lagon:       return [Color(hex: "1ECFC0"), Color(hex: "3A7BD5")]
        case .aurora:      return [Color(hex: "FF6B6B"), Color(hex: "6B3FD4")]
        case .cristal:     return [Color(hex: "F4FAFF"), Color(hex: "FFFFFF")]
        case .saphir:      return [Color(hex: "003D99"), Color(hex: "001F5C")]
        case .nuitEtoilee: return [Color(hex: "1A1A2E"), Color(hex: "16213E")]
        }
    }

    var dropStrokeColor: Color {
        switch self {
        case .givre:                return Color(hex: "2B80D0")
        case .cristal:              return Color(hex: "3A90E0")
        case .minuit, .nuitEtoilee: return Color(hex: "4AABF5")
        default:                    return .white
        }
    }

    var dropFilled: Bool { self == .lagon }
}

// MARK: - AppIconManager

@MainActor
final class AppIconManager: ObservableObject {
    @Published var currentIcon:  AppIcon = .ocean
    @Published var isChanging:   Bool    = false
    @Published var toastMessage: String? = nil

    init() {
        if let name = UIApplication.shared.alternateIconName,
           let icon = AppIcon(rawValue: name) {
            currentIcon = icon
        }
    }

    func setIcon(_ icon: AppIcon, isPremiumUser: Bool) {
        guard !isChanging else { return }
        guard !icon.isPremium || isPremiumUser else { return }
        guard currentIcon != icon else { return }

        #if targetEnvironment(simulator)
        // ── Simulateur ────────────────────────────────────────────────────────
        // setAlternateIconName ne fonctionne pas de façon fiable sur simulateur
        // après le premier appel. On simule le changement directement en mémoire
        // pour pouvoir tester le flux UI sans appareil physique.
        isChanging = true
        Task {
            try? await Task.sleep(for: .seconds(0.4))
            isChanging   = false
            currentIcon  = icon
            toastMessage = String(localized: "profile.app_icon.changed_toast")
            try? await Task.sleep(for: .seconds(2.5))
            toastMessage = nil
        }
        #else
        // ── Appareil physique ─────────────────────────────────────────────────
        guard UIApplication.shared.supportsAlternateIcons else { return }

        isChanging = true

        // setAlternateIconName appelle son completion sur un thread quelconque.
        // nonisolated permet d'appeler cette fonction depuis @MainActor sans
        // que le compilateur exige que le callback soit lui aussi sur le main actor.
        // Task { @MainActor in } ramène les mutations @Published sur le bon thread.
        nonisolated(unsafe) let iconName = icon.alternateIconName
        UIApplication.shared.setAlternateIconName(iconName) { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isChanging = false

                if let error {
                    print("⚠️ setAlternateIconName error: \(error.localizedDescription)")
                }

                // Resynchroniser currentIcon depuis l'état réel d'iOS
                let appliedName = UIApplication.shared.alternateIconName
                if let appliedName, let appliedIcon = AppIcon(rawValue: appliedName) {
                    self.currentIcon = appliedIcon
                } else {
                    self.currentIcon = .ocean
                }

                if self.currentIcon == icon {
                    self.toastMessage = String(localized: "profile.app_icon.changed_toast")
                    try? await Task.sleep(for: .seconds(2.5))
                    self.toastMessage = nil
                }
            }
        }
        #endif
    }

    /// Appelé quand le premium est annulé — remet l'icône Ocean (principale)
    func resetToOceanIfNeeded() {
        guard currentIcon.isPremium else { return }
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(nil) { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self, error == nil else { return }
                self.currentIcon = .ocean
            }
        }
    }
}

// MARK: - AppIconPickerView

struct AppIconPickerView: View {
    @EnvironmentObject var iconManager: AppIconManager
    @EnvironmentObject var storeKit:    StoreKitManager
    @AppStorage("isPremiumUser") private var isPremiumUser: Bool = false
    @State private var showPremiumSheet = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            SectionHeader(
                title:    String(localized: "profile.section.app_icon"),
                sfSymbol: "app.badge",
                color:    Color(hex: "4DA8F5")
            )

            VStack(alignment: .leading, spacing: 0) {

                Text(String(localized: "profile.app_icon.subtitle"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 12)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(AppIcon.allCases) { icon in
                        AppIconCell(
                            icon:       icon,
                            isSelected: iconManager.currentIcon == icon,
                            isUnlocked: !icon.isPremium || isPremiumUser,
                            isChanging: iconManager.isChanging && iconManager.currentIcon == icon
                        ) {
                            if icon.isPremium && !isPremiumUser {
                                showPremiumSheet = true
                            } else {
                                iconManager.setIcon(icon, isPremiumUser: isPremiumUser)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)

                if let toast = iconManager.toastMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 14))
                        Text(toast)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer().frame(height: 14)
            }
            .background(Color("AppCardBackground"))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            .animation(.easeInOut(duration: 0.3), value: iconManager.toastMessage != nil)
        }
        .sheet(isPresented: $showPremiumSheet) {
            PremiumSheet(isPremiumUser: $isPremiumUser, isPresented: $showPremiumSheet)
                .environmentObject(storeKit)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(24)
        }
    }
}

// MARK: - AppIconCell

struct AppIconCell: View {
    let icon:       AppIcon
    let isSelected: Bool
    let isUnlocked: Bool
    let isChanging: Bool
    let onTap:      () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {

                ZStack(alignment: .topTrailing) {

                    // ── Aperçu de l'icône ───────────────────────────────────
                    // Charge l'asset "preview_NomIcone" depuis Assets.xcassets.
                    // Si l'asset n'existe pas encore, fallback sur le dégradé.
                    // → Voir commentaire sur previewAssetName pour les étapes
                    //   à suivre dans Xcode pour ajouter les assets.
                    AppIconPreview(icon: icon)
                        .frame(width: 58, height: 58)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    isSelected ? Color(hex: "4DA8F5") : Color(UIColor.systemGray5),
                                    lineWidth: isSelected ? 2.5 : 1
                                )
                        )
                        .opacity(isUnlocked ? 1.0 : 0.55)
                        .scaleEffect(isChanging ? 0.94 : 1.0)
                        .animation(.spring(response: 0.25), value: isChanging)

                    // Badge couronne (Premium verrouillé)
                    if !isUnlocked {
                        ZStack {
                            Circle().fill(Color.orange).frame(width: 18, height: 18)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 4, y: -4)
                    } else if isSelected {
                        ZStack {
                            Circle().fill(Color(hex: "4DA8F5")).frame(width: 18, height: 18)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 4, y: -4)
                    }
                }
                .frame(width: 62, height: 62)

                // Nom
                Text(icon.localizedName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "4DA8F5") : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Pill état
                Group {
                    if isSelected {
                        Text(String(localized: "profile.app_icon.active_badge"))
                            .foregroundColor(.white)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(hex: "4DA8F5"))
                            .clipShape(Capsule())
                    } else if !icon.isPremium {
                        Text(String(localized: "profile.app_icon.free_label"))
                            .foregroundColor(Color(hex: "2B87E8"))
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(hex: "EEF4FF"))
                            .clipShape(Capsule())
                    } else {
                        Text(String(localized: "profile.app_icon.premium_label"))
                            .foregroundColor(isUnlocked ? .orange : Color(UIColor.systemGray3))
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(isUnlocked ? Color.orange.opacity(0.12) : Color(UIColor.systemGray6))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon.localizedName)
        .accessibilityValue(
            isSelected  ? String(localized: "profile.app_icon.active_badge") :
            !isUnlocked ? String(localized: "profile.app_icon.unlock_hint")  : ""
        )
    }
}

// MARK: - AppIconPreview
// Affiche la vraie image de l'icône depuis un asset dédié "preview_NomIcone".
// Si l'asset est absent, affiche le dégradé de couleur comme fallback.

private struct AppIconPreview: View {
    let icon: AppIcon

    var body: some View {
        if UIImage(named: icon.previewAssetName) != nil {
            // ✅ Asset "preview_Ocean" / "preview_Minuit"… trouvé
            Image(icon.previewAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            // ⚠️ Fallback : dégradé + mini goutte
            // → Ajoute les assets "preview_NomIcone" dans Assets.xcassets
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(
                        colors: icon.backgroundColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                AppDropPreview(icon: icon)
                    .frame(width: 24, height: 30)
            }
            .frame(width: 58, height: 58)
        }
    }
}

// MARK: - AppDropPreview (fallback mini goutte)

struct AppDropPreview: View {
    let icon: AppIcon

    var body: some View {
        if icon.dropFilled {
            DropPathShape()
                .fill(Color.white.opacity(0.92))
        } else {
            DropPathShape()
                .stroke(icon.dropStrokeColor, lineWidth: 3.5)
        }
    }
}

// MARK: - DropPathShape (partagée avec PremiumSheet.swift)

struct DropPathShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p  = Path()
        let cx = rect.midX
        let r  = rect.width / 2.0

        p.move(to: CGPoint(x: cx, y: rect.minY))
        p.addCurve(
            to:       CGPoint(x: cx + r,  y: rect.maxY - r),
            control1: CGPoint(x: cx + r * 0.85, y: rect.minY + rect.height * 0.42),
            control2: CGPoint(x: cx + r,         y: rect.maxY - r * 1.5)
        )
        p.addArc(
            center:     CGPoint(x: cx, y: rect.maxY - r),
            radius:     r,
            startAngle: .degrees(0),
            endAngle:   .degrees(180),
            clockwise:  true
        )
        p.addCurve(
            to:       CGPoint(x: cx, y: rect.minY),
            control1: CGPoint(x: cx - r,          y: rect.maxY - r * 1.5),
            control2: CGPoint(x: cx - r * 0.85,   y: rect.minY + rect.height * 0.42)
        )
        p.closeSubpath()
        return p
    }
}
