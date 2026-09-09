import SwiftUI

struct NameEntryView: View {
    var onComplete: () -> Void

    @State private var firstName: String = ""
    @State private var goToBodyProfile: Bool = false
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            if goToBodyProfile {
                BodyProfileView(onComplete: onComplete)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 20)

                        ZStack {
                            Circle()
                                .fill(Color(hex: "4DA8F5").opacity(0.10))
                                .frame(width: 140, height: 140)
                            Circle()
                                .fill(Color(hex: "4DA8F5").opacity(0.07))
                                .frame(width: 170, height: 170)
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 90, height: 90)
                                    .shadow(color: Color(hex: "4DA8F5").opacity(0.4), radius: 15, x: 0, y: 6)
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.bottom, 28)

                        VStack(spacing: 12) {
                            Text(String(localized: "onboarding.name"))
                                .font(.system(size: 28, weight: .bold))
                                .multilineTextAlignment(.center)
                            Text(String(localized: "onboarding.name_sub"))
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 32)

                        VStack(spacing: 16) {
                            TextField(String(localized: "onboarding.name_placeholder"), text: $firstName)
                                .textContentType(.givenName)
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                                .focused($isFocused)
                                .font(.system(size: 17))
                                .padding(16)
                                .background(Color("AppCardBackground"))
                                .cornerRadius(14)
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(
                                            isFocused ? Color(hex: "4DA8F5") : Color.clear,
                                            lineWidth: 1.5
                                        )
                                )
                                .withDoneButton()
                                .accessibilityIdentifier("onboarding.name")
                                .onSubmit {
                                    if !isButtonDisabled { saveName() }
                                }

                            Button { saveName() } label: {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(
                                        LinearGradient(
                                            colors: isButtonDisabled
                                                ? [Color(UIColor.systemGray3), Color(UIColor.systemGray3)]
                                                : [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(16)
                                    .shadow(
                                        color: isButtonDisabled ? .clear : Color(hex: "4DA8F5").opacity(0.4),
                                        radius: 10, x: 0, y: 4
                                    )
                            }
                            .disabled(isButtonDisabled)
                            .accessibilityIdentifier("onboarding.name.continue")
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, keyboardHeight)
                        .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
                .onAppear { isFocused = true }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                    if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                        withAnimation(.easeOut(duration: 0.25)) {
                            keyboardHeight = keyboardFrame.height - 34
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    withAnimation(.easeOut(duration: 0.25)) {
                        keyboardHeight = 0
                    }
                }
            }
        }
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
