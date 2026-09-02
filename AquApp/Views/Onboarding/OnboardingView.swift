import SwiftUI

// MARK: - OnboardingView
// Racine du NavigationStack d'onboarding.
// Flux : OnboardingView → NameEntryView → BodyProfileView → ContentView

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage:   Int  = 0
    @State private var goToNameEntry: Bool = false

    var pages: [OnboardingPage] {
        [
            OnboardingPage(
                sfSymbol:    "drop.fill",
                color:       Color(hex: "4DA8F5"),
                gradient:    [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
                title:       String(localized: "onboarding.page1.title"),
                description: String(localized: "onboarding.page1.description")
            ),
            OnboardingPage(
                sfSymbol:    "chart.bar.fill",
                color:       Color(hex: "10B981"),
                gradient:    [Color(hex: "10B981"), Color(hex: "059669")],
                title:       String(localized: "onboarding.page2.title"),
                description: String(localized: "onboarding.page2.description")
            ),
            OnboardingPage(
                sfSymbol:    "trophy.fill",
                color:       Color(hex: "F59E0B"),
                gradient:    [Color(hex: "F59E0B"), Color(hex: "D97706")],
                title:       String(localized: "onboarding.page3.title"),
                description: String(localized: "onboarding.page3.description")
            ),
            OnboardingPage(
                sfSymbol:    "bell.badge.fill",
                color:       Color(hex: "9B59B6"),
                gradient:    [Color(hex: "9B59B6"), Color(hex: "6C3483")],
                title:       String(localized: "onboarding.page4.title"),
                description: String(localized: "onboarding.page4.description")
            ),
        ]
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            if goToNameEntry {
                NameEntryView(onComplete: onComplete)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                VStack(spacing: 0) {

                    // Pages swipables
                    TabView(selection: $currentPage) {
                        ForEach(pages.indices, id: \.self) { index in
                            OnboardingPageView(page: pages[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentPage)

                    // Bas : indicateurs + bouton
                    VStack(spacing: 24) {

                        // Points indicateurs
                        HStack(spacing: 8) {
                            ForEach(pages.indices, id: \.self) { index in
                                Capsule()
                                    .fill(index == currentPage
                                          ? pages[currentPage].color
                                          : Color(UIColor.systemGray4))
                                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                                    .animation(.spring(response: 0.3), value: currentPage)
                            }
                        }

                        // Bouton principal
                        Button {
                            if currentPage < pages.count - 1 {
                                withAnimation { currentPage += 1 }
                            } else {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    goToNameEntry = true
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(currentPage < pages.count - 1
                                     ? String(localized: "onboarding.next")
                                     : String(localized: "onboarding.start"))
                                    .font(.system(size: 18, weight: .bold))
                                Image(systemName: currentPage < pages.count - 1
                                      ? "arrow.right"
                                      : "arrow.right.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .accessibilityHidden(true)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: pages[currentPage].gradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: pages[currentPage].color.opacity(0.4), radius: 10, x: 0, y: 4)
                        }
                        .animation(.easeInOut(duration: 0.2), value: currentPage)

                        // Passer
                        if currentPage < pages.count - 1 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    goToNameEntry = true
                                }
                            } label: {
                                Text(String(localized: "onboarding.skip"))
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
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - OnboardingPage model

struct OnboardingPage {
    let sfSymbol:    String
    let color:       Color
    let gradient:    [Color]
    let title:       String
    let description: String
}

// MARK: - OnboardingPageView

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {

            Spacer()

            ZStack {
                Circle()
                    .fill(page.color.opacity(0.12))
                    .frame(width: 160, height: 160)
                Circle()
                    .fill(page.color.opacity(0.08))
                    .frame(width: 200, height: 200)
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: page.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 110)
                        .shadow(color: page.color.opacity(0.4), radius: 20, x: 0, y: 8)
                    Image(systemName: page.sfSymbol)
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(.white)
                }
            }

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 28)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onComplete: {})
}
