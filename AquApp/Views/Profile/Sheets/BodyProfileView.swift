import SwiftUI

struct BodyProfileView: View {
    var onComplete: () -> Void

    @State private var weightKg: Double = 70
    @State private var heightCm: Double = 170
    @State private var selectedGender: Gender = .notSpecified
    @State private var keyboardHeight: CGFloat = 0
    private enum Step { case form, health, reminders }
    @State private var step: Step = .form

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
        case 1800..<2200: return Color.app.primary
        case 2200..<3000: return Color.app.greenDark
        default:          return Color.app.amber
        }
    }

    var body: some View {
        switch step {
        case .form:
            profileForm
                .transition(.move(edge: .leading).combined(with: .opacity))
        case .health:
            HealthPermissionView { go(to: .reminders) }
                .transition(.move(edge: .trailing).combined(with: .opacity))
        case .reminders:
            ReminderPermissionView(onFinish: completeOnboarding)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    private var profileForm: some View {
        ZStack {
            Color.app.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 20)

                    ZStack {
                        Circle()
                            .fill(Color.app.alcoholMid.opacity(0.10))
                            .frame(width: 140, height: 140)
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.app.alcoholMid, Color.app.alcoholDark],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 90, height: 90)
                                .shadow(color: Color.app.alcoholMid.opacity(0.4), radius: 15, x: 0, y: 6)
                            Image(systemName: "person.fill")
                                .scaledFont(size: 40, weight: .medium)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 28)

                    VStack(spacing: 12) {
                        Text(String(localized: "onboarding.body.title"))
                            .scaledFont(size: 28, weight: .bold)
                            .multilineTextAlignment(.center)
                        Text(String(localized: "onboarding.body.sub"))
                            .scaledFont(size: 16)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)

                    VStack(spacing: 24) {
                        // Sexe
                        VStack(alignment: .leading, spacing: 10) {
                            Text(String(localized: "body.gender"))
                                .scaledFont(size: 15, weight: .bold).padding(.horizontal, 4)
                            VStack(spacing: 10) {
                                ForEach(Gender.allCases, id: \.self) { gender in
                                    GenderButton(
                                        gender: gender, isSelected: selectedGender == gender,
                                        accentColor: Color.app.alcoholMid
                                    ) {
                                        withAnimation(.spring(response: 0.25)) { selectedGender = gender }
                                    }
                                }
                            }
                        }

                        // Taille
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "body.height"))
                                .scaledFont(size: 15, weight: .bold).padding(.horizontal, 4)
                            VStack(spacing: 8) {
                                HStack(alignment: .lastTextBaseline, spacing: 6) {
                                    Text("\(Int(UnitFormatter.heightValue(heightCm)))")
                                        .scaledFont(size: 48, weight: .bold)
                                        .foregroundColor(Color.app.primary)
                                    Text(UnitFormatter.heightUnitSymbol)
                                        .scaledFont(size: 18, weight: .medium)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                Slider(value: $heightCm, in: 140...220, step: 1)
                                    .tint(Color.app.primary).padding(.horizontal, 4)
                                    .accessibilityLabel(String(localized: "body.height"))
                                    .accessibilityValue(UnitFormatter.height(heightCm))
                                HStack {
                                    Text(UnitFormatter.heightSliderBound(140))
                                        .scaledFont(size: 11).foregroundColor(.secondary)
                                    Spacer()
                                    Text(UnitFormatter.heightSliderBound(220))
                                        .scaledFont(size: 11).foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                            }
                        }

                        // Poids
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "body.weight"))
                                .scaledFont(size: 15, weight: .bold).padding(.horizontal, 4)
                            VStack(spacing: 8) {
                                HStack(alignment: .lastTextBaseline, spacing: 6) {
                                    Text("\(Int(UnitFormatter.weightValue(weightKg)))")
                                        .scaledFont(size: 48, weight: .bold)
                                        .foregroundColor(Color.app.greenDark)
                                    Text(UnitFormatter.weightUnitSymbol)
                                        .scaledFont(size: 18, weight: .medium)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                Slider(value: $weightKg, in: 30...200, step: 1)
                                    .tint(Color.app.greenDark).padding(.horizontal, 4)
                                    .accessibilityLabel(String(localized: "body.weight"))
                                    .accessibilityValue(UnitFormatter.weight(weightKg))
                                HStack {
                                    Text(UnitFormatter.weightSliderBound(30))
                                        .scaledFont(size: 11).foregroundColor(.secondary)
                                    Spacer()
                                    Text(UnitFormatter.weightSliderBound(200))
                                        .scaledFont(size: 11).foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                            }
                        }

                        // Aperçu objectif
                        HStack(spacing: 12) {
                            Image(systemName: "drop.fill").scaledFont(size: 20).foregroundColor(goalColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "body.new_calculated_goal"))
                                    .scaledFont(size: 13).foregroundColor(.secondary)
                                Text(String(format: String(localized: "body.goal_ml_per_day"), Int(calculatedGoalMl)))
                                    .scaledFont(size: 20, weight: .bold).foregroundColor(goalColor)
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
                                    .scaledFont(size: 16, weight: .semibold)
                                Image(systemName: "arrow.right").scaledFont(size: 16, weight: .bold)
                            }
                            .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 56)
                            .background(LinearGradient(
                                colors: [Color.app.alcoholMid, Color.app.alcoholDark],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .cornerRadius(16)
                            .shadow(color: Color.app.alcoholMid.opacity(0.4), radius: 10, x: 0, y: 4)
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

        go(to: HealthAuthorization.isAvailable ? .health : .reminders)
    }

    private func go(to next: Step) {
        withAnimation(.easeInOut(duration: 0.35)) { step = next }
    }

    // Écrit en dernier : ContentView ferme l'onboarding dès que ce flag passe à true.
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        onComplete()
    }
}

#Preview {
    BodyProfileView(onComplete: {})
}
