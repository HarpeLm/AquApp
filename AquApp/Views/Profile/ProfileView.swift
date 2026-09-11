import SwiftUI
import SwiftData

// MARK: - ProfileView
// Rôle : UNIQUEMENT assembler les sections/components/sheets dédiés.
// Chaque bloc UI vit dans son fichier (Sections/, Components/, Sheets/).

struct ProfileView: View {
    @ObservedObject private var healthStore = HealthDataManager.shared
    @AppStorage("dailyGoalMl") private var dailyGoalMl: Double = 2170
    @AppStorage("selectedBadgeID") private var selectedBadgeID: String = ""
    @AppStorage("colorSchemeRaw") private var colorSchemeRaw: String = "system"
    @AppStorage("notificationsOn") private var notificationsOn: Bool = true
    @ObservedObject private var premiumStore = PremiumManager.shared
    
    private var isPremiumUser: Bool {
        get { premiumStore.isPremium }
        nonmutating set { premiumStore.set(newValue) }
    }
    private var isPremiumUserBinding: Binding<Bool> {
        Binding(get: { premiumStore.isPremium }, set: { premiumStore.set($0) })
    }
    
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var storeKit: StoreKitManager
    @EnvironmentObject var xpManager: XPManager
    @EnvironmentObject var appIconManager: AppIconManager
    @EnvironmentObject var achievementManager: AchievementManager
    @EnvironmentObject var challengeManager: ChallengeManager
    
    @State private var showBadgePicker  = false
    @State private var showGoalEditor   = false
    @State private var showBodyEditor   = false
    @State private var showPremiumSheet = false
    
    var scrollToTopID: UUID = UUID()
    
    init(scrollToTopID: UUID = UUID()) {
        self.scrollToTopID = scrollToTopID
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }
    
    // MARK: - IDs de référence (static let = typés une seule fois, hors expression)

    private static let achievementIDs: [String] = [
        "constance", "semaine_sobre", "sleep_hydrated", "heatwave",
        "perfect_week", "iron_month", "centurion",
        "marathonien", "indestructible", "centurion_sobre",
        "legende", "aqua_addict", "dry_january", "sober_october",
        "no_alcohol_november", "summer_hydration"
    ]

    private static let challengeIDs: [String] = [
        "matinal", "regulier", "grand_buveur", "active_day",
        "soiree_tranquille", "cadence_parfaite", "grand_ecart",
        "flash_hydrate", "recuperation", "matin_champion"
    ]

    var completedAchievements: Int {
        Self.achievementIDs.filter { HealthDataManager.shared.isAchievementCompleted($0) }.count
    }

    var completedChallenges: Int {
        Self.challengeIDs.filter { HealthDataManager.shared.isChallengeCompleted($0) }.count
    }
    
    // MARK: - Badges (cosmétiques + succès + défis)

    private var allBadges: [(id: String, sfSymbol: String, color: Color, title: String, isPro: Bool)] {
        var list: [(id: String, sfSymbol: String, color: Color, title: String, isPro: Bool)] = [
            // ── Cosmétiques gratuits
            (id: "drop",  sfSymbol: "drop.fill",         color: Color(hex: "4DA8F5"), title: "Drop",  isPro: false),
            (id: "wave",  sfSymbol: "waveform.path.ecg", color: Color(hex: "10B981"), title: "Wave",  isPro: false),
            (id: "flame", sfSymbol: "flame.fill",        color: .orange,              title: "Flame", isPro: false),
            (id: "leaf",  sfSymbol: "leaf.fill",         color: .green,               title: "Leaf",  isPro: false),
            (id: "star",  sfSymbol: "star.fill",         color: .yellow,              title: "Star",  isPro: false),
            (id: "bolt",  sfSymbol: "bolt.fill",         color: Color(hex: "F59E0B"), title: "Bolt",  isPro: false),
            (id: "sun",   sfSymbol: "sun.max.fill",      color: .orange,              title: "Sun",   isPro: false),
            (id: "cloud", sfSymbol: "cloud.sun.fill",    color: Color(hex: "4DA8F5"), title: "Cloud", isPro: false),
            // ── Cosmétiques Premium (paliers)
            (id: "crown",   sfSymbol: "crown.fill",      color: .purple,              title: "Crown",   isPro: true),
            (id: "diamond", sfSymbol: "diamond.fill",    color: .cyan,                title: "Diamond", isPro: true),
            (id: "heart",   sfSymbol: "heart.fill",      color: .red,                 title: "Heart",   isPro: true),
            (id: "moon",    sfSymbol: "moon.stars.fill", color: .indigo,              title: "Moon",    isPro: true),
        ]

        // ── Badges de SUCCÈS : générés depuis le manager
        //    (symbole, couleur et titre localisé existent déjà dans Achievement)
        for a in achievementManager.achievements + achievementManager.monthlyAchievements {
            list.append((id: "ach_\(a.id)", sfSymbol: a.sfSymbol, color: a.symbolColor, title: a.title, isPro: a.isPro))
        }

        // ── Badges de DÉFIS : générés depuis le manager
        for c in challengeManager.challenges {
            list.append((id: "cha_\(c.id)", sfSymbol: c.sfSymbol, color: c.symbolColor, title: c.title, isPro: c.isPro))
        }

        return list
    }

    private var unlockedBadgeIDs: Set<String> {
        var unlocked: Set<String> = ["drop", "wave", "flame", "leaf", "star", "bolt", "sun", "cloud"]

        // Paliers cosmétiques Premium
        let total = completedAchievements + completedChallenges
        if total >= 4  { unlocked.insert("crown") }
        if total >= 8  { unlocked.insert("diamond") }
        if total >= 12 { unlocked.insert("heart") }
        if total >= 16 { unlocked.insert("moon") }

        // Succès complétés → badge débloqué
        for a in achievementManager.achievements + achievementManager.monthlyAchievements
        where HealthDataManager.shared.isAchievementCompleted(a.id) {
            unlocked.insert("ach_\(a.id)")
        }

        // Défis complétés → badge débloqué
        for c in challengeManager.challenges
        where HealthDataManager.shared.isChallengeCompleted(c.id) {
            unlocked.insert("cha_\(c.id)")
        }

        return unlocked
    }
    
    // MARK: - Body (assemblage uniquement)
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        Color.clear.frame(height: 0).id("top")
                        
                        // Titre de page
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Profile")
                                .font(.system(size: 32, weight: .bold))
                            Text("Manage your preferences")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // ── SECTION : Header (avatar + nom + badge + stats + XP liquide)
                        ProfileHeaderView(
                            userName: healthStore.firstName.isEmpty ? "User" : healthStore.firstName,
                            isPremiumUser: isPremiumUser,
                            allBadges: allBadges,
                            unlockedBadgeIDs: unlockedBadgeIDs,
                            selectedBadgeID: $selectedBadgeID,
                            showBadgePicker: $showBadgePicker,
                            currentStreak: store.currentStreak,
                            totalCompleted: completedAchievements + completedChallenges,
                            totalWaterLiters: store.totalWaterLiters
                        )
                        .environmentObject(xpManager)
                        
                        // ── COMPONENT : picker de badges (dépliable)
                        if showBadgePicker {
                            BadgePickerSection(
                                allBadges: allBadges,
                                selectedBadgeID: $selectedBadgeID,
                                isPremiumUser: isPremiumUser,
                                unlockedBadgeIDs: unlockedBadgeIDs
                            ) {
                                withAnimation { showBadgePicker = false }
                            }
                            .padding(.horizontal)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
  
                        // ── SECTION : Hydratation (objectif quotidien)
                        ProfileHydrationView(dailyGoalMl: dailyGoalMl) {
                            showGoalEditor = true
                        }
                        
                        // ── SECTION : Profil physique (poids / taille / genre)
                        ProfileBodyView(
                            weightKg: healthStore.weightKg,
                            heightCm: healthStore.heightCm,
                            genderRaw: healthStore.gender
                        ) {
                            showBodyEditor = true
                        }
                        
                        // ── SECTION : Notifications (gère elle-même sa sheet)
                        ProfileNotificationView(notificationsOn: $notificationsOn)
                        
                        // ── SECTION : Apparence (icône d'app + thème)
                        ProfileAppearanceView(colorSchemeRaw: $colorSchemeRaw)
                            .environmentObject(storeKit)
                            .environmentObject(appIconManager)
                        
                        // ── DEBUG : Toggle Premium (à retirer avant release)
                        #if DEBUG
                        Button {
                            let newValue = !isPremiumUser
                            premiumStore.set(newValue)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: isPremiumUser ? "checkmark.seal.fill" : "crown.fill")
                                    .font(.system(size: 16, weight: .bold))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isPremiumUser ? "Premium Actif ✓" : "Activer Premium (Debug)")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(isPremiumUser ? "Tap to disable" : "Tap to enable")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(isPremiumUser ? .green : .orange)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill((isPremiumUser ? Color.green : Color.orange).opacity(0.12))
                            )
                        }
                        .padding(.horizontal)
                        #endif
                        
                        // ── SECTION : bannière Premium (tout en bas, avant les infos)
                        ProfilePremiumBannerView(isPremiumUser: isPremiumUser) {
                            showPremiumSheet = true
                        }
                        
                        // ── Info app
                        appInfoSection
                            .padding(.top, 8)
                        
                        Color.clear.frame(height: 16)
                    }
                    .padding(.bottom, 32)
                }
                .background(Color("AppBackground"))
                .navigationBarHidden(true)
                .onChange(of: scrollToTopID) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("top")
                    }
                }
            }
        }
        // ── SHEETS (fichiers Sheets/) ─────────────────────────────────────
        .sheet(isPresented: $showGoalEditor) {
            GoalEditorSheet(dailyGoalMl: $dailyGoalMl, isPresented: $showGoalEditor)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showBodyEditor) {
            BodyEditSheet(
                weightKg: healthStore.weightBinding,
                heightCm: healthStore.heightBinding,
                genderRaw: healthStore.genderBinding,
                dailyGoalMl: $dailyGoalMl,
                isPresented: $showBodyEditor
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showPremiumSheet) {
            PremiumSheet(isPremiumUser: isPremiumUserBinding, isPresented: $showPremiumSheet)
                .environmentObject(storeKit)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(24)
        }
    }
    
    // MARK: - Seul petit bloc restant en local (spécifique à cette page)
    
    private var appInfoSection: some View {
        VStack(spacing: 4) {
            Text("AquApp")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            Text("Version \(appVersion)")
                .font(.system(size: 12))
                .foregroundColor(Color(UIColor.systemGray3))
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
        configurations: config
    )
    let store = AppDataStore(modelContext: container.mainContext)
    return ProfileView()
        .environmentObject(store)
        .environmentObject(StoreKitManager())
        .environmentObject(XPManager())
        .environmentObject(AppIconManager())
        .environmentObject(AchievementManager())
        .environmentObject(ChallengeManager())    
        .modelContainer(container)
}
