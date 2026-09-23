import SwiftUI

/// Explique l'usage de chaque donnée Santé AVANT la feuille système.
/// Chaque ligne doit correspondre à un type de HealthAuthorization.
struct HealthPermissionView: View {
    var onFinish: () -> Void

    @State private var isRequesting = false

    private struct Row: Identifiable {
        let id = UUID()
        let sfSymbol: String
        let color: Color
        let title: String
        let detail: String
    }

    private var rows: [Row] {
        [
            Row(sfSymbol: "drop.fill", color: Color(hex: "4DA8F5"),
                title: String(localized: "health.permission.water.title"),
                detail: String(localized: "health.permission.water.detail")),
            Row(sfSymbol: "figure.walk", color: Color(hex: "10B981"),
                title: String(localized: "health.permission.steps.title"),
                detail: String(localized: "health.permission.steps.detail")),
            Row(sfSymbol: "figure.run", color: Color(hex: "F59E0B"),
                title: String(localized: "health.permission.workouts.title"),
                detail: String(localized: "health.permission.workouts.detail")),
            Row(sfSymbol: "bed.double.fill", color: Color(hex: "9B59B6"),
                title: String(localized: "health.permission.sleep.title"),
                detail: String(localized: "health.permission.sleep.detail")),
        ]
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .fill(Color.pink.opacity(0.10))
                            .frame(width: 140, height: 140)
                        Circle()
                            .fill(LinearGradient(colors: [Color.pink, Color.red],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 90, height: 90)
                            .shadow(color: Color.pink.opacity(0.4), radius: 15, x: 0, y: 6)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .accessibilityHidden(true)
                    .padding(.top, 60)

                    VStack(spacing: 12) {
                        Text(String(localized: "health.permission.title"))
                            .font(.system(size: 28, weight: .bold))
                            .multilineTextAlignment(.center)
                        Text(String(localized: "health.permission.subtitle"))
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: row.sfSymbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(row.color)
                                    .frame(width: 36, height: 36)
                                    .background(row.color.opacity(0.12))
                                    .clipShape(Circle())
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(row.title)
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(row.detail)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 12)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(Color("AppCardBackground"))
                    .cornerRadius(16)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                        Text(String(localized: "health.permission.privacy"))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 14) {
                        Button { connect() } label: {
                            Group {
                                if isRequesting {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(String(localized: "health.permission.connect"))
                                        .font(.system(size: 17, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(LinearGradient(colors: [Color.pink, Color.red],
                                                       startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(16)
                        }
                        .disabled(isRequesting)
                        .accessibilityIdentifier("onboarding.health.connect")

                        Button { finish() } label: {
                            Text(String(localized: "health.permission.later"))
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .disabled(isRequesting)
                        .accessibilityIdentifier("onboarding.health.later")
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }

    private func connect() {
        isRequesting = true
        Task {
            await HealthAuthorization.request()
            isRequesting = false
            finish()
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: HealthAuthorization.offeredKey)
        onFinish()
    }
}

#Preview {
    HealthPermissionView(onFinish: {})
}
