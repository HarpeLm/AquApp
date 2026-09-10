import SwiftUI

// MARK: - GoalEditorSheet

struct GoalEditorSheet: View {
    @Binding var dailyGoalMl: Double
    @Binding var isPresented: Bool

    @State private var localGoal: Double = 2170

    private let presets: [Double] = [1500, 2000, 2500, 3000]

    private var goalColor: Color {
        switch localGoal {
        case ..<1800:     return .orange
        case 1800..<2200: return Color(hex: "4DA8F5")
        case 2200..<3000: return Color(hex: "10B981")
        default:          return Color(hex: "F59E0B")
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(UIColor.systemGray4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // Header
            HStack {
                HStack(spacing: 8) {
                    Text(String(localized: "goal.editor.title"))
                        .font(.system(size: 22, weight: .bold))
                    Image(systemName: "drop.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "4DA8F5"))
                }
                Spacer()
                Button { isPresented = false } label: {
                    ZStack {
                        Circle().fill(Color(UIColor.systemGray5)).frame(width: 32, height: 32)
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityLabel(String(localized: "goal.editor.close"))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 24) {

                    // Valeur courante
                    VStack(spacing: 6) {
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text("\(Int(localGoal))")
                                .font(.system(size: 52, weight: .bold))
                                .foregroundColor(goalColor)
                            Text("ml")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Text(String(localized: "goal.editor.subtitle"))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // Slider objectif
                    VStack(spacing: 8) {
                        Slider(value: $localGoal, in: 500...5000, step: 50)
                            .tint(goalColor)
                            .padding(.horizontal, 20)
                            .accessibilityLabel(String(localized: "goal.editor.title"))
                            .accessibilityValue("\(Int(localGoal)) ml")
                        HStack {
                            Text("500 ml")
                                .font(.system(size: 11)).foregroundColor(.secondary)
                            Spacer()
                            Text("5000 ml")
                                .font(.system(size: 11)).foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 24)
                    }

                    // Presets rapides
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "goal.editor.presets"))
                            .font(.system(size: 15, weight: .bold))
                            .padding(.horizontal, 20)
                        HStack(spacing: 10) {
                            ForEach(presets, id: \.self) { value in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { localGoal = value }
                                } label: {
                                    Text("\(Int(value))")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(localGoal == value ? .white : goalColor)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(
                                            localGoal == value
                                            ? AnyShapeStyle(goalColor)
                                            : AnyShapeStyle(goalColor.opacity(0.12))
                                        )
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Note canicule
                    HStack(spacing: 12) {
                        Image(systemName: "thermometer.sun.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.red)
                        Text(String(localized: "goal.editor.heatwave_note"))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.red.opacity(0.06))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.red.opacity(0.15), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    // Bouton enregistrer
                    Button {
                        dailyGoalMl = localGoal
                        isPresented = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 18))
                            Text(String(localized: "body.save_and_update"))
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(LinearGradient(
                            colors: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .cornerRadius(16)
                        .shadow(color: Color(hex: "4DA8F5").opacity(0.4), radius: 10, x: 0, y: 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .accessibilityIdentifier("goal.editor.save")
                }
                .padding(.top, 8)
            }
        }
        .background(Color("AppBackground"))
        .ignoresSafeArea(edges: .bottom)
        .accessibilityIdentifier("sheet.goal")   // ← requis par test08
        .onAppear { localGoal = dailyGoalMl }
    }
}

// MARK: - Preview

#Preview {
    GoalEditorSheet(dailyGoalMl: .constant(2170), isPresented: .constant(true))
}
