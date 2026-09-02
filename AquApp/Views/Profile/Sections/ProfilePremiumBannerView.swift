import SwiftUI

struct ProfilePremiumBannerView: View {
    let isPremiumUser: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var bannerBackground: Color { colorScheme == .dark ? Color(hex: "2D1F00") : Color(hex: "FFF7ED") }
    var bannerBorder:     Color { Color.orange.opacity(colorScheme == .dark ? 0.35 : 0.30) }
    var titleColor:       Color { colorScheme == .dark ? Color(hex: "FCD34D") : Color(hex: "92400E") }
    var subtitleColor:    Color { colorScheme == .dark ? Color(hex: "F59E0B").opacity(0.75) : Color(hex: "B45309") }
    var chevronColor:     Color { colorScheme == .dark ? Color(hex: "F59E0B") : Color(hex: "B45309") }

    var body: some View {
        if isPremiumUser {

            // Carte "abonné actif"
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(colorScheme == .dark ? 0.20 : 0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.orange)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(L10n.premiumActive)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(titleColor)
                        Text(String(localized: "profile.pro_label"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? Color(hex: "1C1400") : .white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(hex: "F59E0B")).cornerRadius(6)
                    }
                    Text(L10n.premiumAllUnlocked)
                        .font(.system(size: 13))
                        .foregroundColor(subtitleColor)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color(hex: "10B981"))
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(bannerBackground)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(bannerBorder, lineWidth: 1))
            .padding(.horizontal)

        } else {

            // Bannière "passer à Premium"
            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(colorScheme == .dark ? 0.18 : 0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "crown.fill")
                            .accessibilityHidden(true)
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.premiumUpgrade)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(titleColor)
                        Text(L10n.premiumUpgradeSub)
                            .font(.system(size: 13))
                            .foregroundColor(subtitleColor)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .accessibilityHidden(true)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(chevronColor)
                }
                .padding(16)
                .background(bannerBackground)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(bannerBorder, lineWidth: 1))
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ProfilePremiumBannerView(isPremiumUser: false, onTap: {})
        ProfilePremiumBannerView(isPremiumUser: true,  onTap: {})
    }
    .padding(.vertical)
    .background(Color("AppBackground"))
}
