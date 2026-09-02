import SwiftUI

// MARK: - SharedComponents
// Types partagés entre BodyProfileView et ProfileBodyView.
// Centralisés ici pour éviter les conflits de scope entre fichiers.

// MARK: - Gender

enum Gender: String, CaseIterable {
    case male         = "male"
    case female       = "female"
    case notSpecified = "notSpecified"

    var label: String {
        switch self {
        case .male:         return String(localized: "gender.male")
        case .female:       return String(localized: "gender.female")
        case .notSpecified: return String(localized: "gender.not_specified")
        }
    }

    var sfSymbol: String {
        switch self {
        case .male:         return "person.fill"
        case .female:       return "person.fill"
        case .notSpecified: return "person.fill.questionmark"
        }
    }

    var icon: String {
        switch self {
        case .male:         return "♂"
        case .female:       return "♀"
        case .notSpecified: return "○"
        }
    }
}

// MARK: - GenderButton

struct GenderButton: View {
    let gender:      Gender
    let isSelected:  Bool
    let accentColor: Color
    let action:      () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? accentColor.opacity(0.15) : Color(UIColor.systemGray6))
                        .frame(width: 44, height: 44)
                    Text(gender.icon)
                        .font(.system(size: 20))
                }

                Text(gender.label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? accentColor : .primary)

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? accentColor : Color(UIColor.systemGray4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                isSelected
                    ? accentColor.opacity(0.06)
                    : Color("AppCardBackground")
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? accentColor.opacity(0.5) : Color(UIColor.systemGray5),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(gender.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected
            ? String(localized: "gender.button.hint.selected")
            : String(localized: "gender.button.hint.unselected"))
    }
}

// MARK: - ProfileRecapCell

struct ProfileRecapCell: View {
    let icon:  String
    let color: Color
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .accessibilityHidden(true)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
}
