import SwiftUI

struct ProfilePremiumBannerView: View {
    let isPremiumUser: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var bannerBackground: Color { colorScheme == .dark ? Color.app.premiumDark : Color.app.warmWhite }
    var bannerBorder:     Color { Color.orange.opacity(colorScheme == .dark ? 0.35 : 0.30) }
    var titleColor:       Color { colorScheme == .dark ? Color.app.premiumGold : Color.app.amberText }
    var subtitleColor:    Color { colorScheme == .dark ? Color.app.amber.opacity(0.75) : Color.app.amberDeep }
    var chevronColor:     Color { colorScheme == .dark ? Color.app.amber : Color.app.amberDeep }

    var body: some View {
        if isPremiumUser {

            // Carte "abonné actif"
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(colorScheme == .dark ? 0.20 : 0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "crown.fill")
                        .scaledFont(size: 22)
                        .foregroundColor(.orange)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(L10n.premiumActive)
                            .scaledFont(size: 16, weight: .bold)
                            .foregroundColor(titleColor)
                        Text(String(localized: "profile.pro_label"))
                            .scaledFont(size: 10, weight: .bold)
                            .foregroundColor(colorScheme == .dark ? Color.app.premiumDarker : .white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.app.amber).cornerRadius(6)
                    }
                    Text(L10n.premiumAllUnlocked)
                        .scaledFont(size: 13)
                        .foregroundColor(subtitleColor)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .scaledFont(size: 22)
                    .foregroundColor(Color.app.greenDark)
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
                            .scaledFont(size: 20)
                            .foregroundColor(.orange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.premiumUpgrade)
                            .scaledFont(size: 16, weight: .bold)
                            .foregroundColor(titleColor)
                        Text(L10n.premiumUpgradeSub)
                            .scaledFont(size: 13)
                            .foregroundColor(subtitleColor)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .accessibilityHidden(true)
                        .scaledFont(size: 13, weight: .semibold)
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
    .background(Color.app.background)
}
