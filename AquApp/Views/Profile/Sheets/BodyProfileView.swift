import SwiftUI

// MARK: - BodyProfileView
// Collecte le sexe, la taille et le poids de l'utilisateur
// et calcule l'objectif d'hydratation journalier.
// Flux : OnboardingView → NameEntryView → BodyProfileView → ContentView

struct BodyProfileView: View {
    var onComplete: () -> Void

    // MARK: - État local
    @State private var currentStep:    Int    = 0
    @State private var selectedGender: Gender = .notSpecified
    @State private var heightCm:       Double = 170
    @State private var weightKg:       Double = 70
    @State private var showResult:     Bool   = false

    // MARK: - Couleurs par étape
    let stepColors: [[Color]] = [
        [Color(hex: "9B59B6"), Color(hex: "6C3483")],
        [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
        [Color(hex: "10B981"), Color(hex: "059669")],
    ]
    let stepColorsMid: [Color] = [
        Color(hex: "9B59B6"),
        Color(hex: "4DA8F5"),
        Color(hex: "10B981"),
    ]

    var currentGradient: [Color] { stepColors[min(currentStep, 2)] }
    var currentColor:    Color   { stepColorsMid[min(currentStep, 2)] }

    // MARK: - Calcul de l'objectif
    var calculatedGoalMl: Double {
        let base      = weightKg * 35
        let heightAdj = (heightCm - 170) * 5
        let genderAdj: Double
        switch selectedGender {
        case .male:         genderAdj = 200
        case .female:       genderAdj = 0
        case .notSpecified: genderAdj = 100
        }
        return min(max(round((base + heightAdj + genderAdj) / 50) * 50, 1000), 5000)
    }

    var goalLabel: String {
        switch calculatedGoalMl {
        case ..<1800:     return String(localized: "goal.label.below")
        case 1800..<2200: return String(localized: "goal.label.recommended")
        case 2200..<3000: return String(localized: "goal.label.good")
        default:          return String(localized: "goal.label.sport")
        }
    }

    var goalColor: Color {
        switch calculatedGoalMl {
        case ..<1800:     return .orange
        case 1800..<2200: return Color(hex: "4DA8F5")
        case 2200..<3000: return Color(hex: "10B981")
        default:          return Color(hex: "F59E0B")
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            if showResult {
                resultView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                stepView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: currentStep)
        .animation(.easeInOut(duration: 0.35), value: showResult)
    }

    // MARK: - Vue étapes

    var stepView: some View {
        VStack(spacing: 0) {

            // Indicateurs d'étapes
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Capsule()
                        .fill(index <= currentStep ? currentColor : Color(UIColor.systemGray4))
                        .frame(width: index == currentStep ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentStep)
                }
            }
            .padding(.top, 56)
            .padding(.bottom, 32)

            Group {
                switch currentStep {
                case 0:  genderStep
                case 1:  heightStep
                case 2:  weightStep
                default: genderStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 16) {
                Button {
                    if currentStep < 2 {
                        withAnimation { currentStep += 1 }
                    } else {
                        withAnimation { showResult = true }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(currentStep < 2
                             ? String(localized: "body.step.next")
                             : String(localized: "body.step.see_goal"))
                            .font(.system(size: 18, weight: .bold))
                        Image(systemName: currentStep < 2 ? "arrow.right" : "checkmark.circle.fill")
                            .accessibilityHidden(true)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(LinearGradient(
                        colors: currentGradient,
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .cornerRadius(16)
                    .shadow(color: currentColor.opacity(0.4), radius: 10, x: 0, y: 4)
                }

                if currentStep > 0 {
                    Button { withAnimation { currentStep -= 1 } } label: {
                        Text(String(localized: "body.step.back"))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Color.clear.frame(height: 20)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Étape 1 : Sexe

    var genderStep: some View {
        VStack(spacing: 32) {
            stepIcon(sfSymbol: "person.fill", gradient: stepColors[0], color: stepColorsMid[0])

            VStack(spacing: 12) {
                Text(String(localized: "body.step.gender.title"))
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(String(localized: "body.step.gender.sub"))
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)

            VStack(spacing: 12) {
                ForEach(Gender.allCases, id: \.self) { gender in
                    GenderButton(
                        gender: gender,
                        isSelected: selectedGender == gender,
                        accentColor: stepColorsMid[0]
                    ) {
                        withAnimation(.spring(response: 0.25)) { selectedGender = gender }
                    }
                }
            }
            .padding(.horizontal, 28)

            Spacer()
        }
    }

    // MARK: - Étape 2 : Taille

    var heightStep: some View {
        VStack(spacing: 32) {
            stepIcon(sfSymbol: "ruler.fill", gradient: stepColors[1], color: stepColorsMid[1])

            VStack(spacing: 12) {
                Text(String(localized: "body.step.height.title"))
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(String(localized: "body.step.height.sub"))
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)

            VStack(spacing: 4) {
                Text(UnitFormatter.volumeNumber(Double(heightCm)) == "\(Int(heightCm))"
                     ? "\(Int(UnitFormatter.heightValue(heightCm)))"
                     : "\(Int(UnitFormatter.heightValue(heightCm)))")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(stepColorsMid[1])
                    .animation(.none, value: heightCm)
                Text(UnitFormatter.heightUnitSymbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                Slider(value: $heightCm, in: 140...220, step: 1)
                    .tint(stepColorsMid[1])
                    .padding(.horizontal, 28)
                    .accessibilityLabel(String(localized: "body.height"))
                    .accessibilityValue(UnitFormatter.height(heightCm))
                HStack {
                    Text(UnitFormatter.heightSliderBound(140)).font(.system(size: 12)).foregroundColor(.secondary)
                    Spacer()
                    Text(UnitFormatter.heightSliderBound(220)).font(.system(size: 12)).foregroundColor(.secondary)
                }
                .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Étape 3 : Poids

    var weightStep: some View {
        VStack(spacing: 32) {
            stepIcon(sfSymbol: "scalemass.fill", gradient: stepColors[2], color: stepColorsMid[2])

            VStack(spacing: 12) {
                Text(String(localized: "body.step.weight.title"))
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(String(localized: "body.step.weight.sub"))
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)

            VStack(spacing: 4) {
                Text("\(Int(UnitFormatter.weightValue(weightKg)))")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(stepColorsMid[2])
                    .animation(.none, value: weightKg)
                Text(UnitFormatter.weightUnitSymbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                Slider(value: $weightKg, in: 30...200, step: 1)
                    .tint(stepColorsMid[2])
                    .padding(.horizontal, 28)
                    .accessibilityLabel(String(localized: "body.weight"))
                    .accessibilityValue(UnitFormatter.weight(weightKg))
                HStack {
                    Text(UnitFormatter.weightSliderBound(30)).font(.system(size: 12)).foregroundColor(.secondary)
                    Spacer()
                    Text(UnitFormatter.weightSliderBound(200)).font(.system(size: 12)).foregroundColor(.secondary)
                }
                .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Vue résultat

    var resultView: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle().fill(goalColor.opacity(0.12)).frame(width: 160, height: 160)
                Circle().fill(goalColor.opacity(0.08)).frame(width: 200, height: 200)
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [goalColor, goalColor.opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 110, height: 110)
                        .shadow(color: goalColor.opacity(0.4), radius: 20, x: 0, y: 8)
                    Image(systemName: "drop.fill")
                        .accessibilityHidden(true)
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(.white)
                }
            }

            VStack(spacing: 16) {
                Text(String(localized: "body.result.title"))
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(UnitFormatter.volumeNumber(calculatedGoalMl))
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(goalColor)
                    Text(UnitFormatter.volumeUnitSymbol)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Text(goalLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(goalColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(goalColor.opacity(0.1))
                    .cornerRadius(20)
            }
            .padding(.top, 32)
            .padding(.horizontal, 28)

            HStack(spacing: 0) {
                ProfileRecapCell(icon: selectedGender.sfSymbol, color: Color(hex: "9B59B6"), value: selectedGender.label)
                Divider().frame(height: 40)
                ProfileRecapCell(icon: "ruler.fill",      color: Color(hex: "4DA8F5"), value: UnitFormatter.height(heightCm))
                Divider().frame(height: 40)
                ProfileRecapCell(icon: "scalemass.fill",  color: Color(hex: "10B981"), value: UnitFormatter.weight(weightKg))
            }
            .padding(.vertical, 16)
            .background(Color("AppCardBackground"))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 28)
            .padding(.top, 32)

            Spacer()

            VStack(spacing: 16) {
                Button { saveAndContinue() } label: {
                    HStack(spacing: 8) {
                        Text(String(localized: "body.result.cta"))
                            .font(.system(size: 18, weight: .bold))
                        Image(systemName: "arrow.right")
                            .accessibilityHidden(true)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(LinearGradient(
                        colors: [goalColor, goalColor.opacity(0.75)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .cornerRadius(16)
                    .shadow(color: goalColor.opacity(0.4), radius: 10, x: 0, y: 4)
                }

                Button { withAnimation { showResult = false; currentStep = 0 } } label: {
                    Text(String(localized: "body.result.modify"))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Helpers UI

    func stepIcon(sfSymbol: String, gradient: [Color], color: Color) -> some View {
        ZStack {
            Circle().fill(color.opacity(0.12)).frame(width: 160, height: 160)
            Circle().fill(color.opacity(0.08)).frame(width: 200, height: 200)
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 110, height: 110)
                    .shadow(color: color.opacity(0.4), radius: 20, x: 0, y: 8)
                Image(systemName: sfSymbol)
                    .accessibilityHidden(true)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Sauvegarde

    func saveAndContinue() {
        // Garde-fou : les sliders bornent déjà 30...200 kg et 140...220 cm,
        // mais on sécurise quand même la valeur persistée pour éviter toute
        // dérive silencieuse (ex. valeur restaurée depuis un ancien état).
        let safeWeight = weightKg.isFinite ? min(max(weightKg, 30), 200) : 70
        let safeHeight = heightCm.isFinite ? min(max(heightCm, 140), 220) : 170
        let safeGoal   = calculatedGoalMl.isFinite ? min(max(calculatedGoalMl, 500), 5000) : 2170

        UserDefaults.standard.set(safeWeight,               forKey: "userWeightKg")
        UserDefaults.standard.set(safeHeight,               forKey: "userHeightCm")
        UserDefaults.standard.set(selectedGender.rawValue, forKey: "userGender")
        UserDefaults.standard.set(safeGoal,                forKey: "dailyGoalMl")
        UserDefaults.standard.set(true,                    forKey: "onboardingCompleted")
        onComplete()
    }
}

// MARK: - Preview

#Preview {
    BodyProfileView(onComplete: {})
}
