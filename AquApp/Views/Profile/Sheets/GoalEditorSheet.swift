import SwiftUI

// MARK: - GoalEditorSheet

struct GoalEditorSheet: View {
    @Binding var dailyGoalMl: Double
    @Binding var isPresented: Bool

    @State private var localGoal: Double = 2000

    @AppStorage("userWeightKg") private var weightKg: Double = 70
    @AppStorage("userHeightCm") private var heightCm: Double = 170
    @AppStorage("userGender")   private var genderRaw: String = "notSpecified"

    var calculatedGoalFromProfile: Double {
        let base      = weightKg * 35
        let heightAdj = (heightCm - 170) * 5
        let genderAdj: Double
        switch genderRaw {
        case "male":   genderAdj = 200
        case "female": genderAdj = 0
        default:       genderAdj = 100
        }
        return min(max(round((base + heightAdj + genderAdj) / 50) * 50, 1000), 5000)
    }

    var hasBodyProfile: Bool {
        UserDefaults.standard.object(forKey: "userWeightKg") != nil
    }

    var suggestions: [(label: String, sublabel: String, ml: Double, sfSymbol: String, color: Color)] {
        [
            (label: String(localized: "goal.suggestion.sedentary"),  sublabel: String(localized: "goal.suggestion.sedentary.sub"),  ml: 1500, sfSymbol: "sofa.fill",                           color: Color(hex: "94A3B8")),
            (label: String(localized: "goal.suggestion.light"),      sublabel: String(localized: "goal.suggestion.light.sub"),      ml: 2000, sfSymbol: "figure.walk",                         color: Color(hex: "4DA8F5")),
            (label: String(localized: "goal.suggestion.active"),     sublabel: String(localized: "goal.suggestion.active.sub"),     ml: 2500, sfSymbol: "figure.run",                          color: Color(hex: "10B981")),
            (label: String(localized: "goal.suggestion.intensive"),  sublabel: String(localized: "goal.suggestion.intensive.sub"),  ml: 3500, sfSymbol: "figure.strengthtraining.traditional", color: Color(hex: "F59E0B")),
        ]
    }

    var goalLabel: String {
        switch localGoal {
        case ..<1800:     return String(localized: "goal.label.below")
        case 1800..<2200: return String(localized: "goal.label.recommended")
        case 2200..<3000: return String(localized: "goal.label.good")
        default:          return String(localized: "goal.label.sport")
        }
    }

    var goalColor: Color {
        switch localGoal {
        case ..<1800:     return .orange
        case 1800..<2200: return Color(hex: "4DA8F5")
        case 2200..<3000: return Color(hex: "10B981")
        default:          return Color(hex: "F59E0B")
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            RoundedRectangle(cornerRadius: 3)
                .fill(Color(UIColor.systemGray4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)

            HStack {
                HStack(spacing: 8) {
                    Text(String(localized: "goal.editor.title"))
                        .font(.system(size: 22, weight: .bold))
                    Image(systemName: "target")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "4DA8F5"))
                        .accessibilityHidden(true)
                }
                Spacer()
                Button { isPresented = false } label: {
                    ZStack {
                        Circle().fill(Color(UIColor.systemGray5)).frame(width: 32, height: 32)
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                    }
                }
                .accessibilityLabel(String(localized: "goal.editor.close"))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 16) {

                    // Valeur + label dynamique
                    VStack(spacing: 6) {
                        Text(String(localized: "goal.editor.your_goal"))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text(UnitFormatter.volumeNumber(localGoal))
                                .font(.system(size: 52, weight: .bold))
                                .foregroundColor(.primary)
                                .animation(.spring(), value: localGoal)
                            Text(UnitFormatter.volumeUnitSymbol)
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 6) {
                            Circle().fill(goalColor).frame(width: 8, height: 8)
                            Text(goalLabel)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(goalColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(goalColor.opacity(0.1))
                        .cornerRadius(20)
                        .animation(.easeInOut, value: goalLabel)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)

                    // Slider
                    VStack(spacing: 6) {
                        Slider(value: $localGoal, in: UnitFormatter.goalSliderRange, step: 50)
                            .tint(goalColor)
                            .accessibilityLabel(String(localized: "goal.editor.your_goal"))
                            .accessibilityValue(UnitFormatter.volume(localGoal))
                        HStack {
                            Text(UnitFormatter.volumeSliderBound(500)).font(.system(size: 11)).foregroundColor(.secondary)
                            Spacer()
                            Text(UnitFormatter.volumeSliderBound(5000)).font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Recalcul depuis le profil physique
                    if hasBodyProfile {
                        Button {
                            withAnimation(.spring()) { localGoal = calculatedGoalFromProfile }
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "4DA8F5").opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "person.fill.checkmark")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "4DA8F5"))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(localized: "goal.editor.recalculate"))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(hex: "4DA8F5"))
                                    Text(String(format: String(localized: "goal.editor.recalculate_sub"), UnitFormatter.weight(weightKg), UnitFormatter.height(Double(heightCm)), UnitFormatter.volume(calculatedGoalFromProfile)))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "4DA8F5"))
                            }
                            .padding(14)
                            .background(Color(hex: "4DA8F5").opacity(0.06))
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "4DA8F5").opacity(0.2), lineWidth: 1))
                        }
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Suggestions rapides
                    SuggestionGridView(suggestions: suggestions, localGoal: $localGoal)

                    // Retour valeur recommandée
                    if Int(localGoal) != Int(calculatedGoalFromProfile) && hasBodyProfile {
                        Button {
                            withAnimation(.spring()) { localGoal = calculatedGoalFromProfile }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise").font(.system(size: 13))
                                Text(String(format: String(localized: "goal.editor.reset_to_profile"), UnitFormatter.volume(calculatedGoalFromProfile)))
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.secondary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    } else if Int(localGoal) != 2170 && !hasBodyProfile {
                        Button {
                            withAnimation(.spring()) { localGoal = 2170 }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise").font(.system(size: 13))
                                Text(String(localized: "goal.editor.reset_to_default"))
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.secondary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Bouton enregistrer
                    Button {
                        dailyGoalMl = localGoal
                        isPresented = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 18))
                            Text(String(localized: "goal.editor.save"))
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(LinearGradient(
                            colors: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Color("AppBackground"))
        .ignoresSafeArea(edges: .bottom)
        .onAppear { localGoal = dailyGoalMl }
    }
}

// MARK: - SuggestionGridView

private struct SuggestionGridView: View {
    let suggestions: [(label: String, sublabel: String, ml: Double, sfSymbol: String, color: Color)]
    @Binding var localGoal: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "goal.editor.suggestions"))
                .font(.system(size: 15, weight: .bold))
                .padding(.horizontal, 20)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(suggestions, id: \.ml) { suggestion in
                    SuggestionCard(suggestion: suggestion, localGoal: $localGoal)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - SuggestionCard

private struct SuggestionCard: View {
    let suggestion: (label: String, sublabel: String, ml: Double, sfSymbol: String, color: Color)
    @Binding var localGoal: Double

    var isSelected: Bool { Int(localGoal) == Int(suggestion.ml) }

    var body: some View {
        Button { withAnimation(.spring()) { localGoal = suggestion.ml } } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(suggestion.color.opacity(isSelected ? 0.2 : 0.1))
                        .frame(width: 38, height: 38)
                    Image(systemName: suggestion.sfSymbol)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(suggestion.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? suggestion.color : .primary)
                    Text(suggestion.sublabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AnyShapeStyle(suggestion.color.opacity(0.08)) : AnyShapeStyle(Color("AppCardBackground")))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? suggestion.color.opacity(0.4) : Color.clear, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }
}

#Preview {
    GoalEditorSheet(dailyGoalMl: .constant(2170), isPresented: .constant(true))
}
