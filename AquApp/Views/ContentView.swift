import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("colorSchemeRaw")      private var colorSchemeRaw:      String = "system"
    @AppStorage("onboardingCompleted") private var onboardingCompleted: Bool   = false
    @EnvironmentObject var confettiManager: ConfettiManager

    @State private var showAddWaterFromWidget = false
    @State private var showDBRecoveryAlert    = false

    // MARK: - Scroll-to-top
    // selectedTab   : onglet actif, lié au TabView.
    // scrollToTopID : UUID régénéré à chaque re-tap sur l'onglet déjà actif.
    // Chaque vue ScrollView observe ce UUID via .onChange(of: scrollToTopID)
    // et appelle proxy.scrollTo("top") avec animation quand il change.
    @State private var selectedTab:   Int  = 0
    @State private var scrollToTopID: UUID = UUID()

    var dbRecoveryError: Error?

    var preferredColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light":  return .light
        case "dark":   return .dark
        default:       return nil
        }
    }

    var body: some View {
        ZStack {
            TabView(selection: Binding(
                get: { selectedTab },
                set: { newTab in
                    if newTab == selectedTab {
                        // Re-tap sur l'onglet déjà actif → scroll-to-top
                        scrollToTopID = UUID()
                    }
                    selectedTab = newTab
                }
            )) {
                HomeView(
                    openAddWater:  $showAddWaterFromWidget,
                    scrollToTopID: scrollToTopID
                )
                .tabItem { Label(String(localized: "tab.home"), systemImage: "house") }
                .tag(0)

                StatsView(scrollToTopID: scrollToTopID)
                    .tabItem { Label(String(localized: "tab.stats"), systemImage: "chart.bar") }
                    .tag(1)

                ChallengesView(scrollToTopID: scrollToTopID)
                    .tabItem { Label(String(localized: "tab.challenges"), systemImage: "trophy") }
                    .tag(2)

                AchievementsView(scrollToTopID: scrollToTopID)
                    .tabItem { Label(String(localized: "tab.achievements"), systemImage: "rosette") }
                    .tag(3)

                ProfileView(scrollToTopID: scrollToTopID)
                    .tabItem { Label(String(localized: "tab.profile"), systemImage: "person.crop.circle") }
                    .tag(4)
            }
            .tint(Color.blue)

            ConfettiOverlayView()
                .environmentObject(confettiManager)
        }
        .preferredColorScheme(preferredColorScheme)
        .fullScreenCover(isPresented: Binding(
            get: { !onboardingCompleted },
            set: { isShowing in
                if !isShowing { onboardingCompleted = true }
            }
        )) {
            OnboardingView {
                onboardingCompleted = true
            }
        }
        .onOpenURL { url in
            if url.host == "addwater" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showAddWaterFromWidget = true
                }
            }
        }
        .alert(String(localized: "db.recovery.title"), isPresented: $showDBRecoveryAlert) {
            Button(String(localized: "db.recovery.confirm"), role: .cancel) {}
        } message: {
            Text(dbRecoveryError?.localizedDescription
                 ?? String(localized: "db.recovery.fallback_message"))
        }
        .onAppear {
            if dbRecoveryError != nil {
                showDBRecoveryAlert = true
            }
        }
    }
}
