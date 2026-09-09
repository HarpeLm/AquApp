import SwiftUI

// MARK: - ProfileBodyView

struct ProfileBodyView: View {
    let weightKg:  Double
    let heightCm:  Double
    let genderRaw: String
    let onTap:     () -> Void

    var genderLabel: String {
        switch genderRaw {
        case "male":   return String(localized: "gender.male")
        case "female": return String(localized: "gender.female")
        default:       return String(localized: "gender.not_specified")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                title:    String(localized: "profile.section.body"),
                sfSymbol: "person.fill",
                color:    Color(hex: "9B59B6")
            )

            Button(action: onTap) {
                VStack(spacing: 0) {
                    ProfileBodyRow(
                        sfSymbol: "scalemass.fill",
                        color:    Color(hex: "10B981"),
                        label:    String(localized: "body.weight"),
                        value:    UnitFormatter.weight(weightKg)
                    )
                    Divider().padding(.leading, 52)
                    ProfileBodyRow(
                        sfSymbol: "ruler.fill",
                        color:    Color(hex: "4DA8F5"),
                        label:    String(localized: "body.height"),
                        value:    UnitFormatter.height(heightCm)
                    )
                    Divider().padding(.leading, 52)
                    ProfileBodyRow(
                        sfSymbol:    "person.fill",
                        color:       Color(hex: "9B59B6"),
                        label:       String(localized: "body.gender"),
                        value:       genderLabel,
                        showChevron: true
                    )
                }
                .background(Color("AppCardBackground"))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }
}

// MARK: - ProfileBodyRow

private struct ProfileBodyRow: View {
    let sfSymbol:    String
    let color:       Color
    let label:       String
    let value:       String
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: sfSymbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
            }
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color(UIColor.systemGray3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - BodyEditSheet

struct BodyEditSheet: View {
    @Binding var weightKg:    Double
    @Binding var heightCm:    Double
    @Binding var genderRaw:   String
    @Binding var dailyGoalMl: Double
    @Binding var isPresented: Bool

    @State private var localWeight: Double = 70
    @State private var localHeight: Double = 170
    @State private var localGender: Gender = .notSpecified

    var calculatedGoal: Double {
        let safeWeight = localWeight.isFinite ? min(max(localWeight, 30), 200)  : 70
        let safeHeight = localHeight.isFinite ? min(max(localHeight, 140), 220) : 170

        let base      = safeWeight * 35
        let heightAdj = (safeHeight - 170) * 5
        let genderAdj: Double
        switch localGender {
        case .male:         genderAdj = 200
        case .female:       genderAdj = 0
        case .notSpecified: genderAdj = 100
        }
        return min(max(round((base + heightAdj + genderAdj) / 50) * 50, 1000), 5000)
    }

    var goalColor: Color {
        switch calculatedGoal {
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
                .padding(.top, 12).padding(.bottom, 16)

            HStack {
                HStack(spacing: 8) {
                    Text(String(localized: "profile.section.body"))
                        .font(.system(size: 22, weight: .bold))
                    Image(systemName: "person.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "9B59B6"))
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
            .padding(.horizontal, 20).padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 24) {

                    // Sexe
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "body.gender"))
                            .font(.system(size: 15, weight: .bold)).padding(.horizontal, 20)
                        VStack(spacing: 10) {
                            ForEach(Gender.allCases, id: \.self) { gender in
                                GenderButton(
                                    gender: gender, isSelected: localGender == gender,
                                    accentColor: Color(hex: "9B59B6")
                                ) {
                                    withAnimation(.spring(response: 0.25)) { localGender = gender }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Taille
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "body.height"))
                            .font(.system(size: 15, weight: .bold)).padding(.horizontal, 20)
                        VStack(spacing: 8) {
                            HStack(alignment: .lastTextBaseline, spacing: 6) {
                                Text("\(Int(UnitFormatter.heightValue(localHeight)))")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(Color(hex: "4DA8F5"))
                                Text(UnitFormatter.heightUnitSymbol)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            Slider(value: $localHeight, in: 140...220, step: 1)
                                .tint(Color(hex: "4DA8F5")).padding(.horizontal, 20)
                                .accessibilityLabel(String(localized: "body.height"))
                                .accessibilityValue(UnitFormatter.height(localHeight))
                            HStack {
                                Text(UnitFormatter.heightSliderBound(140))
                                    .font(.system(size: 11)).foregroundColor(.secondary)
                                Spacer()
                                Text(UnitFormatter.heightSliderBound(220))
                                    .font(.system(size: 11)).foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 24)
                        }
                    }

                    // Poids
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "body.weight"))
                            .font(.system(size: 15, weight: .bold)).padding(.horizontal, 20)
                        VStack(spacing: 8) {
                            HStack(alignment: .lastTextBaseline, spacing: 6) {
                                Text("\(Int(UnitFormatter.weightValue(localWeight)))")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(Color(hex: "10B981"))
                                Text(UnitFormatter.weightUnitSymbol)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            Slider(value: $localWeight, in: 30...200, step: 1)
                                .tint(Color(hex: "10B981")).padding(.horizontal, 20)
                                .accessibilityLabel(String(localized: "body.weight"))
                                .accessibilityValue(UnitFormatter.weight(localWeight))
                            HStack {
                                Text(UnitFormatter.weightSliderBound(30))
                                    .font(.system(size: 11)).foregroundColor(.secondary)
                                Spacer()
                                Text(UnitFormatter.weightSliderBound(200))
                                    .font(.system(size: 11)).foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 24)
                        }
                    }

                    // Aperçu objectif
                    HStack(spacing: 12) {
                        Image(systemName: "drop.fill").font(.system(size: 20)).foregroundColor(goalColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "body.new_calculated_goal"))
                                .font(.system(size: 13)).foregroundColor(.secondary)
                            Text(String(format: String(localized: "body.goal_ml_per_day"), Int(calculatedGoal)))
                                .font(.system(size: 20, weight: .bold)).foregroundColor(goalColor)
                        }
                        Spacer()
                    }
                    .padding(16).background(goalColor.opacity(0.08)).cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(goalColor.opacity(0.2), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .animation(.easeInOut, value: calculatedGoal)

                    // Bouton enregistrer
                    Button { save() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 18))
                            Text(String(localized: "body.save_and_update"))
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 54)
                        .background(LinearGradient(
                            colors: [Color(hex: "9B59B6"), Color(hex: "6C3483")],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .cornerRadius(16)
                        .shadow(color: Color(hex: "9B59B6").opacity(0.4), radius: 10, x: 0, y: 4)
                    }
                    .padding(.horizontal, 20).padding(.bottom, 32)
                }
                .padding(.top, 8)
            }
        }
        .background(Color("AppBackground"))
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            localWeight = weightKg
            localHeight = heightCm
            localGender = Gender(rawValue: genderRaw) ?? .notSpecified
        }
    }

    private func save() {
        // Garde-fou : les sliders bornent déjà 30...200 kg et 140...220 cm,
        // mais on sécurise quand même la valeur persistée.
        let safeWeight = localWeight.isFinite  ? min(max(localWeight, 30), 200)   : 70
        let safeHeight = localHeight.isFinite  ? min(max(localHeight, 140), 220)  : 170
        let safeGoal   = calculatedGoal.isFinite ? min(max(calculatedGoal, 500), 5000) : 2170

        weightKg    = safeWeight
        heightCm    = safeHeight
        genderRaw   = localGender.rawValue
        dailyGoalMl = safeGoal
        UserDefaults.standard.set(safeWeight,           forKey: "userWeightKg")
        UserDefaults.standard.set(safeHeight,           forKey: "userHeightCm")
        UserDefaults.standard.set(localGender.rawValue, forKey: "userGender")
        UserDefaults.standard.set(safeGoal,             forKey: "dailyGoalMl")
        isPresented = false
    }
}

// MARK: - Preview

#Preview {
    ProfileBodyView(weightKg: 75, heightCm: 178, genderRaw: "male") {}
        .padding(.vertical)
        .background(Color("AppBackground"))
}
