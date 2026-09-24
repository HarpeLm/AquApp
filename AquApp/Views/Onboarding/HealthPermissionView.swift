import SwiftUI

// MARK: - Écran d'autorisation générique (Santé, rappels)

/// Explique pourquoi l'app demande une autorisation AVANT la feuille système,
/// avec toujours une option « Plus tard ».
struct PermissionPromptView: View {
    struct Row: Identifiable {
        let id = UUID()
        let sfSymbol: String
        let color: Color
        let title: String
        let detail: String
    }

    let sfSymbol: String
    let gradient: [Color]
    let title: String
    let subtitle: String
    let rows: [Row]
    let footnote: String
    let footnoteSymbol: String
    let confirmTitle: String
    let laterTitle: String
    let identifierPrefix: String
    /// Demande système ; l'écran se ferme ensuite quel que soit le résultat.
    let onConfirm: () async -> Void
    let onFinish: () -> Void

    @State private var isRequesting = false

    var body: some View {
        ZStack {
            Color.app.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .fill(gradient[0].opacity(0.10))
                            .frame(width: 140, height: 140)
                        Circle()
                            .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 90, height: 90)
                            .shadow(color: gradient[0].opacity(0.4), radius: 15, x: 0, y: 6)
                        Image(systemName: sfSymbol)
                            .scaledFont(size: 40, weight: .medium)
                            .foregroundColor(.white)
                    }
                    .accessibilityHidden(true)
                    .padding(.top, 60)

                    VStack(spacing: 12) {
                        Text(title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text(subtitle)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: row.sfSymbol)
                                    .scaledFont(size: 18, weight: .semibold)
                                    .foregroundColor(row.color)
                                    .frame(width: 36, height: 36)
                                    .background(row.color.opacity(0.12))
                                    .clipShape(Circle())
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(row.title)
                                        .font(.body.weight(.semibold))
                                    Text(row.detail)
                                        .font(.subheadline)
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
                    .background(Color.app.card)
                    .cornerRadius(16)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: footnoteSymbol)
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                        Text(footnote)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 14) {
                        Button { confirm() } label: {
                            Group {
                                if isRequesting {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(confirmTitle).font(.headline)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 56)
                            .background(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(16)
                        }
                        .disabled(isRequesting)
                        .accessibilityIdentifier("\(identifierPrefix).connect")

                        Button { onFinish() } label: {
                            Text(laterTitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .disabled(isRequesting)
                        .accessibilityIdentifier("\(identifierPrefix).later")
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }

    private func confirm() {
        isRequesting = true
        Task {
            await onConfirm()
            isRequesting = false
            onFinish()
        }
    }
}

// MARK: - Apple Santé

/// Chaque ligne doit correspondre à un type de HealthAuthorization.
struct HealthPermissionView: View {
    var onFinish: () -> Void

    var body: some View {
        PermissionPromptView(
            sfSymbol: "heart.fill",
            gradient: [.pink, .red],
            title: String(localized: "health.permission.title"),
            subtitle: String(localized: "health.permission.subtitle"),
            rows: [
                .init(sfSymbol: "drop.fill", color: Color.app.primary,
                      title: String(localized: "health.permission.water.title"),
                      detail: String(localized: "health.permission.water.detail")),
                .init(sfSymbol: "figure.walk", color: Color.app.greenDark,
                      title: String(localized: "health.permission.steps.title"),
                      detail: String(localized: "health.permission.steps.detail")),
                .init(sfSymbol: "figure.run", color: Color.app.amber,
                      title: String(localized: "health.permission.workouts.title"),
                      detail: String(localized: "health.permission.workouts.detail")),
                .init(sfSymbol: "bed.double.fill", color: Color.app.alcoholMid,
                      title: String(localized: "health.permission.sleep.title"),
                      detail: String(localized: "health.permission.sleep.detail")),
            ],
            footnote: String(localized: "health.permission.privacy"),
            footnoteSymbol: "lock.fill",
            confirmTitle: String(localized: "health.permission.connect"),
            laterTitle: String(localized: "health.permission.later"),
            identifierPrefix: "onboarding.health",
            onConfirm: { await HealthAuthorization.request() },
            onFinish: {
                UserDefaults.standard.set(true, forKey: HealthAuthorization.offeredKey)
                onFinish()
            }
        )
    }
}

// MARK: - Rappels

/// Active les rappels avec les réglages par défaut (modifiables dans Profil).
struct ReminderPermissionView: View {
    var onFinish: () -> Void

    private var scheduleDetail: String {
        String(format: String(localized: "reminder.permission.schedule.detail"),
               ReminderScheduler.intervalHours, ReminderScheduler.startHour, ReminderScheduler.endHour)
    }

    var body: some View {
        PermissionPromptView(
            sfSymbol: "bell.badge.fill",
            gradient: [Color.app.alcoholMid, Color.app.alcoholDark],
            title: String(localized: "reminder.permission.title"),
            subtitle: String(localized: "reminder.permission.subtitle"),
            rows: [
                .init(sfSymbol: "clock.fill", color: Color.app.primary,
                      title: String(localized: "reminder.permission.schedule.title"),
                      detail: scheduleDetail),
                .init(sfSymbol: "moon.zzz.fill", color: Color.app.alcoholMid,
                      title: String(localized: "reminder.permission.night.title"),
                      detail: String(localized: "reminder.permission.night.detail")),
                .init(sfSymbol: "slider.horizontal.3", color: Color.app.greenDark,
                      title: String(localized: "reminder.permission.adjust.title"),
                      detail: String(localized: "reminder.permission.adjust.detail")),
            ],
            footnote: String(localized: "reminder.permission.footnote"),
            footnoteSymbol: "iphone",
            confirmTitle: String(localized: "reminder.permission.enable"),
            laterTitle: String(localized: "reminder.permission.later"),
            identifierPrefix: "onboarding.reminders",
            onConfirm: {
                let granted = await ReminderScheduler.requestAuthorization()
                UserDefaults.standard.set(granted, forKey: ReminderScheduler.enabledKey)
                if granted {
                    await ReminderScheduler.schedule(start: ReminderScheduler.startHour,
                                                     end: ReminderScheduler.endHour,
                                                     interval: ReminderScheduler.intervalHours)
                }
            },
            onFinish: onFinish
        )
    }
}

#Preview("Santé") {
    HealthPermissionView(onFinish: {})
}

#Preview("Rappels") {
    ReminderPermissionView(onFinish: {})
}
