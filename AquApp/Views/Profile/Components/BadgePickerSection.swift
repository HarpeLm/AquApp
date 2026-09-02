//
//  BadgePickerSection.swift
//  AquApp
//
//  Created by Fabian Dargaud on 15/03/2026.
//
import SwiftUI

struct BadgePickerSection: View {
    let allBadges: [(id: String, sfSymbol: String, color: Color, title: String, isPro: Bool)]
    @Binding var selectedBadgeID: String
    let isPremiumUser: Bool
    let unlockedBadgeIDs: Set<String>
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "profile.choose_badge"))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .accessibilityHidden(true)
                        .foregroundColor(Color(UIColor.systemGray3))
                        .font(.system(size: 20))
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                spacing: 12
            ) {
                ForEach(allBadges, id: \.id) { badge in
                    let isLocked = (badge.isPro && !isPremiumUser) || !unlockedBadgeIDs.contains(badge.id)
                    let isSelected = selectedBadgeID == badge.id

                    Button {
                        if !isLocked {
                            selectedBadgeID = isSelected ? "" : badge.id
                            onClose()
                        }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(isSelected
                                          ? badge.color.opacity(0.2)
                                          : Color(UIColor.secondarySystemBackground))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Circle()
                                            .stroke(isSelected ? badge.color : Color.clear, lineWidth: 2)
                                    )

                                Image(systemName: badge.sfSymbol)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(isLocked ? Color(UIColor.systemGray3) : badge.color)
                                    .accessibilityHidden(true)

                                if isLocked {
                                    Image(systemName: "lock.fill")
                                        .accessibilityHidden(true)
                                        .font(.system(size: 10))
                                        .foregroundColor(.white)
                                        .padding(3)
                                        .background(Color(UIColor.systemGray3))
                                        .clipShape(Circle())
                                        .offset(x: 16, y: -16)
                                        .accessibilityHidden(true)
                                }
                            }

                            Text(badge.title)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(isLocked ? Color(UIColor.systemGray3) : .primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .opacity(isLocked ? 0.5 : 1.0)
                    }
                    .disabled(isLocked)
                    .accessibilityLabel(badge.title)
                    .accessibilityValue(isLocked
                        ? String(localized: "accessibility.locked_premium")
                        : (isSelected
                            ? String(localized: "badge.picker.value.selected")
                            : String(localized: "badge.picker.value.unselected")))
                    .accessibilityHint(isLocked
                        ? String(localized: "accessibility.premium_required_hint")
                        : (isSelected
                            ? String(localized: "badge.picker.hint.remove")
                            : String(localized: "badge.picker.hint.equip")))
                }
            }
        }
        .padding(16)
        .background(Color("AppCardBackground"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}
