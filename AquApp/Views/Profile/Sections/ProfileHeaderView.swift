import SwiftUI

// MARK: - ProfileHeaderView
// Carte unifiée : avatar · nom · badge · stats · barre XP liquide

struct ProfileHeaderView: View {

    let userName:        String
    let isPremiumUser:   Bool
    let allBadges:       [(id: String, sfSymbol: String, color: Color, title: String, isPro: Bool)]
    let unlockedBadgeIDs: Set<String>
    @Binding var selectedBadgeID: String
    @Binding var showBadgePicker: Bool

    // Stats injectées depuis ProfileView
    let currentStreak:         Int
    let totalCompleted:        Int
    let totalWaterLiters:      Double

    // XP
    @EnvironmentObject var xpManager: XPManager

    // ── Helpers ───────────────────────────────────────────────────────────────
    var selectedBadge: (id: String, sfSymbol: String, color: Color, title: String, isPro: Bool)? {
        allBadges.first { $0.id == selectedBadgeID }
    }

    var avatarColor: Color {
        let colors: [Color] = [
            Color(hex: "4DA8F5"), Color(hex: "9B59B6"),
            Color(hex: "10B981"), Color(hex: "F59E0B")
        ]
        return colors[abs(userName.hashValue) % colors.count]
    }

    var initials: String {
        let parts = userName.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last  = parts.count > 1 ? (parts.last?.prefix(1) ?? "") : ""
        return "\(first)\(last)".uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Ligne avatar + nom ────────────────────────────────────────────
            HStack(spacing: 16) {

                // Avatar
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [avatarColor, avatarColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 64, height: 64)
                    Text(initials.isEmpty ? "?" : initials)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                // Halo subtil selon la couleur du niveau
                .shadow(color: xpManager.currentLevel.color.opacity(0.35), radius: 8, x: 0, y: 2)
                .accessibilityHidden(true)

                // Nom + badge
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(userName)
                            .font(.system(size: 20, weight: .bold))
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                        if let badge = selectedBadge {
                            ZStack {
                                Circle()
                                    .fill(badge.color.opacity(0.15))
                                    .frame(width: 30, height: 30)
                                Image(systemName: badge.sfSymbol)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(badge.color)
                            }
                            .accessibilityLabel(String(format: String(localized: "profile.badge_label"), badge.title))
                        }
                    }

                    Button {
                        withAnimation(.spring()) { showBadgePicker.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "medal.fill")
                                .font(.system(size: 11))
                                .accessibilityHidden(true)
                            Text(selectedBadge == nil
                                 ? String(localized: "profile.choose_badge")
                                 : String(localized: "profile.change_badge"))
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "4DA8F5"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "EEF4FF"))
                        .cornerRadius(8)
                    }
                    .accessibilityLabel(selectedBadge == nil
                                        ? String(localized: "profile.choose_badge")
                                        : String(localized: "profile.change_badge"))
                    .accessibilityHint(String(localized: "profile.badge.accessibility_hint"))
                }

                Spacer()

                // Badge PRO
                if isPremiumUser {
                    VStack(spacing: 2) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                            .accessibilityHidden(true)
                        Text(String(localized: "profile.pro_label"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    .accessibilityLabel(String(localized: "profile.premium_active_label"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // ── Divider ───────────────────────────────────────────────────────
            Divider().padding(.horizontal, 20)

            // ── Stats ─────────────────────────────────────────────────────────
            HStack(spacing: 0) {
                ProfileStatCell(
                    value:  "\(currentStreak)",
                    label:  String(localized: "profile.stats.streak"),
                    color:  .orange,
                    symbol: "flame.fill"
                )
                Divider().frame(height: 36)
                ProfileStatCell(
                    value:  "\(totalCompleted)",
                    label:  String(localized: "profile.stats.achievements"),
                    color:  Color(hex: "4DA8F5"),
                    symbol: "star.fill"
                )
                Divider().frame(height: 36)
                ProfileStatCell(
                    value:  String(format: "%.1f L", totalWaterLiters),
                    label:  String(localized: "profile.stats.total_water"),
                    color:  Color(hex: "10B981"),
                    symbol: "drop.fill"
                )
            }
            .padding(.vertical, 14)

            // ── Divider ───────────────────────────────────────────────────────
            Divider().padding(.horizontal, 20)

            // ── Bloc XP liquide ───────────────────────────────────────────────
            XPProgressBlock(xp: xpManager)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 18)
        }
        .background(Color("AppCardBackground"))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 3)
        // Halo coloré subtil selon le niveau
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "4DA8F5").opacity(0.20),
                            Color(hex: "4DA8F5").opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .padding(.horizontal)
    }
}

// MARK: - ProfileStatCell

struct ProfileStatCell: View {
    let value:  String
    let label:  String
    let color:  Color
    let symbol: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11))
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

// MARK: - XPProgressBlock

private struct XPProgressBlock: View {

    @ObservedObject var xp: XPManager
    @State private var animatedProgress: Double = 0

    var levelColor: Color { xp.currentLevel.color }
    var isMaxLevel: Bool  { xp.currentLevel.next == nil }

    var body: some View {
        VStack(spacing: 0) {

            // ── Ligne niveau + fraction XP ────────────────────────────────────
            HStack(alignment: .center) {

                // Pastille niveau
                HStack(spacing: 7) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "4DA8F5").opacity(0.13))
                            .frame(width: 22, height: 22)
                        Circle()
                            .fill(xp.currentLevel.displayColor)
                            .frame(width: 9, height: 9)
                            .shadow(color: xp.currentLevel.displayColor.opacity(0.5), radius: 4, x: 0, y: 0)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(localized: "xp.level.label") + " \(xp.currentLevel.rawValue)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(xp.currentLevel.localizedName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(xp.currentLevel.displayColor)
                    }
                }

                Spacer()

                // XP dans le niveau courant
                if isMaxLevel {
                    Text(String(localized: "xp.max_level"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(xp.currentLevel.displayColor)
                } else {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(xp.xpInCurrentLevel) / \(xp.currentLevelRange) XP")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .padding(.bottom, 10)

            // ── Barre liquide ─────────────────────────────────────────────────
            LiquidXPBar(
                progress: animatedProgress,
                color:    xp.currentLevel.displayColor,
                height:   10
            )
            .padding(.bottom, 8)

            // ── Pied de bloc ──────────────────────────────────────────────────
            HStack {
                // Total cumulé
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(xp.currentLevel.displayColor)
                        .accessibilityHidden(true)
                    Text(String(format: String(localized: "xp.total_cumulated"), xp.totalXP))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Prochain niveau
                if let remaining = xp.xpUntilNextLevel,
                   let nextLevel = xp.currentLevel.next {
                    Text(String(format: String(localized: "xp.until_next_level"), remaining, nextLevel.localizedName))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2)) {
                animatedProgress = xp.progressRatio
            }
        }
        .onChange(of: xp.progressRatio) { _, newValue in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                animatedProgress = newValue
            }
        }
        .onChange(of: xp.didLevelUp) { _, leveledUp in
            guard leveledUp else { return }
            withAnimation(.easeOut(duration: 0.15)) { animatedProgress = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    animatedProgress = xp.progressRatio
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "xp.accessibility.level_label"), xp.currentLevel.rawValue, xp.currentLevel.localizedName))
        .accessibilityValue(
            xp.xpUntilNextLevel.map { String(format: String(localized: "xp.accessibility.xp_remaining"), $0) }
            ?? String(localized: "xp.accessibility.max_level")
        )
    }
}

// MARK: - Preview

#Preview {
    let xp = XPManager()
    ProfileHeaderView(
        userName:          "Fabian Dargaud",
        isPremiumUser:     true,
        allBadges:         [],
        unlockedBadgeIDs:  [],
        selectedBadgeID:   .constant(""),
        showBadgePicker:   .constant(false),
        currentStreak:     12,
        totalCompleted:    8,
        totalWaterLiters:  48.3
    )
    .environmentObject(xp)
    .padding(.vertical)
    .background(Color("AppBackground"))
}
