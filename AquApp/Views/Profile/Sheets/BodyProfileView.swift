import SwiftUI

struct BodyProfileView: View {
    var onComplete: () -> Void

    @State private var weightKg: Double = 70
    @State private var heightCm: Double = 170
    @State private var selectedGender: Gender = .notSpecified
    @State private var keyboardHeight: CGFloat = 0

    var calculatedGoalMl: Double {
        let safeWeight = weightKg.isFinite ? min(max(weightKg, 30), 200) : 70
        let safeHeight = heightCm.isFinite ? min(max(heightCm, 140), 220) : 170
        let base       = safeWeight * 35
        let heightAdj  = (safeHeight - 170) * 5
        let genderAdj: Double
        switch selectedGender {
        case .male:         genderAdj = 200
        case .female:       genderAdj = 0
        case .notSpecified: genderAdj = 100
        }
        return min(max(round((base + heightAdj + genderAdj) / 50) * 50, 1000), 5000)
    }

    var goalColor: Color {
        switch calculatedGoalMl {
        case ..<1800:     return .orange
        case 1800..<2200: return Color(hex: "4DA8F5")
        case 2200..<3000: return Color(hex: "10B981")
        default:          return Color(hex: "F59E0B")
        }
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 20)

                    ZStack {
                        Circle()
                            .fill(Color(hex: "9B59B6").opacity(0.10))
                            .frame(width: 140, height: 140)
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "9B59B6"), Color(hex: "6C3483")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 90, height: 90)
                                .shadow(color: Color(hex: "9B59B6").opacity(0.4), radius: 15, x: 0, y: 6)
                            Image(systemName: "person.fill")
                                .font(.system(size: 40, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 28)

                    VStack(spacing: 12) {
                        Text(String(localized: "onboarding.body.title"))
                            .font(.system(size: 28, weight: .bold))
                            .multilineTextAlignment(.center)
                        Text(String(localized: "onboarding.body.sub"))
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)

                    VStack(spacing: 24) {
                        // Sexe
                        VStack(alignment: .leading, spacing: 10) {
                            Text(String(localized: "body.gender"))
                                .font(.system(size: 15, weight: .bold)).padding(.horizontal, 4)
                            VStack(spacing: 10) {
                                ForEach(Gender.allCases, id: \.self) { gender in
                                    GenderButton(
                                        gender: gender, isSelected: selectedGender == gender,
                                        accentColor: Color(hex: "9B59B6")
                                    ) {
                                        withAnimation(.spring(response: 0.25)) { selectedGender = gender }
                                    }
                                }
                            }
                        }

                        // Taille
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "body.height"))
                                .font(.system(size: 15, weight: .bold)).padding(.horizontal, 4)
                            VStack(spacing: 8) {
                                HStack(alignment: .lastTextBaseline, spacing: 6) {
                                    Text("\(Int(UnitFormatter.heightValue(heightCm)))")
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundColor(Color(hex: "4DA8F5"))
                                    Text(UnitFormatter.heightUnitSymbol)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                Slider(value: $heightCm, in: 140...220, step: 1)
                                    .tint(Color(hex: "4DA8F5")).padding(.horizontal, 4)
                                    .accessibilityLabel(String(localized: "body.height"))
                                    .accessibilityValue(UnitFormatter.height(heightCm))
                                HStack {
                                    Text(UnitFormatter.heightSliderBound(140))
                                        .font(.system(size: 11)).foregroundColor(.secondary)
                                    Spacer()
                                    Text(UnitFormatter.heightSliderBound(220))
                                        .font(.system(size: 11)).foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                            }
                        }

                        // Poids
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "body.weight"))
                                .font(.system(size: 15, weight: .bold)).padding(.horizontal, 4)
                            VStack(spacing: 8) {
                                HStack(alignment: .lastTextBaseline, spacing: 6) {
                                    Text("\(Int(UnitFormatter.weightValue(weightKg)))")
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundColor(Color(hex: "10B981"))
                                    Text(UnitFormatter.weightUnitSymbol)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                Slider(value: $weightKg, in: 30...200, step: 1)
                                    .tint(Color(hex: "10B981")).padding(.horizontal, 4)
                                    .accessibilityLabel(String(localized: "body.weight"))
                                    .accessibilityValue(UnitFormatter.weight(weightKg))
                                HStack {
                                    Text(UnitFormatter.weightSliderBound(30))
                                        .font(.system(size: 11)).foregroundColor(.secondary)
                                    Spacer()
                                    Text(UnitFormatter.weightSliderBound(200))
                                        .font(.system(size: 11)).foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                            }
                        }

                        // Aperçu objectif
                        HStack(spacing: 12) {
                            Image(systemName: "drop.fill").font(.system(size: 20)).foregroundColor(goalColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "body.new_calculated_goal"))
                                    .font(.system(size: 13)).foregroundColor(.secondary)
                                Text(String(format: String(localized: "body.goal_ml_per_day"), Int(calculatedGoalMl)))
                                    .font(.system(size: 20, weight: .bold)).foregroundColor(goalColor)
                            }
                            Spacer()
                        }
                        .padding(16).background(goalColor.opacity(0.08)).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(goalColor.opacity(0.2), lineWidth: 1))
                        .animation(.easeInOut, value: calculatedGoalMl)

                        // Bouton
                        Button { saveAndContinue() } label: {
                            HStack(spacing: 8) {
                                Text(String(localized: "body.save_and_continue"))
                                    .font(.system(size: 16, weight: .semibold))
                                Image(systemName: "arrow.right").font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 56)
                            .background(LinearGradient(
                                colors: [Color(hex: "9B59B6"), Color(hex: "6C3483")],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .cornerRadius(16)
                            .shadow(color: Color(hex: "9B59B6").opacity(0.4), radius: 10, x: 0, y: 4)
                            .accessibilityIdentifier("onboarding.body.save")
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, keyboardHeight)
                    .padding(.bottom, 20)
                }
            }
        }
        .ignoresSafeArea()
    }

    func saveAndContinue() {
        let safeWeight = weightKg.isFinite ? min(max(weightKg, 30), 200) : 70
        let safeHeight = heightCm.isFinite ? min(max(heightCm, 140), 220) : 170
        let safeGoal   = calculatedGoalMl.isFinite ? min(max(calculatedGoalMl, 500), 5000) : 2170

        HealthDataManager.shared.setWeight(safeWeight)
        HealthDataManager.shared.setHeight(safeHeight)
        HealthDataManager.shared.setGender(selectedGender.rawValue)
        UserDefaults.standard.set(safeGoal, forKey: "dailyGoalMl")
        UserDefaults.standard.set(true,     forKey: "onboardingCompleted")
        onComplete()
    }
}

#Preview {
    BodyProfileView(onComplete: {})
}
