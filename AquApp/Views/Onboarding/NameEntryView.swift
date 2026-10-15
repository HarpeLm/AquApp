import SwiftUI

struct NameEntryView: View {
    var onComplete: () -> Void

    @State private var firstName: String = ""
    @State private var goToBodyProfile: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.app.background.ignoresSafeArea()

            if goToBodyProfile {
                BodyProfileView(onComplete: onComplete)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                // iOS gère le clavier (zone de sécurité) : le contenu se centre dans l'espace
                // restant, sous la barre d'état et au-dessus du clavier.
                GeometryReader { geo in
                    ScrollView {
                        VStack(spacing: 0) {
                            Spacer(minLength: 16)
                            avatar
                                .padding(.bottom, isFocused ? 18 : 28)
                            titles
                                .padding(.bottom, isFocused ? 24 : 32)
                            form
                            Spacer(minLength: 16)
                        }
                        .frame(maxWidth: .infinity, minHeight: geo.size.height)
                        .animation(.easeOut(duration: 0.25), value: isFocused)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollDismissesKeyboard(.interactively)
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
                .onAppear { isFocused = true }
            }
        }
    }

    // MARK: - Sous-vues

    /// Plus compact quand le clavier est ouvert, pour que tout tienne au-dessus.
    private var avatar: some View {
        let scale: CGFloat = isFocused ? 0.72 : 1
        return ZStack {
            Circle()
                .fill(Color.app.primary.opacity(0.10))
                .frame(width: 140 * scale, height: 140 * scale)
            Circle()
                .fill(Color.app.primary.opacity(0.07))
                .frame(width: 170 * scale, height: 170 * scale)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.app.primary, Color.app.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90 * scale, height: 90 * scale)
                    .shadow(color: Color.app.primary.opacity(0.4), radius: 15, x: 0, y: 6)
                Image(systemName: "person.fill")
                    .scaledFont(size: 40 * scale, weight: .medium)
                    .foregroundColor(.white)
            }
        }
        .accessibilityHidden(true)
    }

    private var titles: some View {
        VStack(spacing: 12) {
            Text(String(localized: "onboarding.name"))
                .scaledFont(size: 28, weight: .bold)
                .multilineTextAlignment(.center)
            Text(String(localized: "onboarding.name_sub"))
                .scaledFont(size: 16)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
    }

    private var form: some View {
        VStack(spacing: 16) {
            TextField(String(localized: "onboarding.name_placeholder"), text: $firstName)
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isFocused)
                .scaledFont(size: 17)
                .padding(16)
                .background(Color.app.card)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isFocused ? Color.app.primary : Color.clear,
                            lineWidth: 1.5
                        )
                )
                .accessibilityIdentifier("onboarding.name")
                .onSubmit {
                    if !isButtonDisabled { saveName() }
                }

            Button { saveName() } label: {
                Image(systemName: "arrow.right")
                    .scaledFont(size: 18, weight: .bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: isButtonDisabled
                                ? [Color(UIColor.systemGray3), Color(UIColor.systemGray3)]
                                : [Color.app.primary, Color.app.primaryDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(
                        color: isButtonDisabled ? .clear : Color.app.primary.opacity(0.4),
                        radius: 10, x: 0, y: 4
                    )
            }
            .disabled(isButtonDisabled)
            .accessibilityIdentifier("onboarding.name.continue")
        }
        .padding(.horizontal, 28)
    }

    private var isButtonDisabled: Bool {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveName() {
        let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        HealthDataManager.shared.setFirstName(trimmed)
        isFocused = false
        withAnimation(.easeInOut(duration: 0.35)) {
            goToBodyProfile = true
        }
    }
}

#Preview {
    NameEntryView(onComplete: {})
}
