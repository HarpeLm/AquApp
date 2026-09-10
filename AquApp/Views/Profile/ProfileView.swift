import SwiftUI
import SwiftData

struct ProfileView: View {
    @ObservedObject private var healthStore = HealthDataManager.shared
    @AppStorage("dailyGoalMl") private var dailyGoalMl: Double = 2170
    @AppStorage("selectedBadgeID") private var selectedBadgeID: String = ""
    @ObservedObject private var premiumStore = PremiumManager.shared
    
    private var isPremiumUser: Bool {
        get { premiumStore.isPremium }
        nonmutating set { premiumStore.set(newValue) }
    }
    
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var storeKit: StoreKitManager
    @EnvironmentObject var xpManager: XPManager
    @EnvironmentObject var achievementManager: AchievementManager
    @EnvironmentObject var challengeManager: ChallengeManager
    
    @State private var showBadgePicker = false
    @State private var showGoalEditor = false
    @State private var showBodyEditor = false
    
    var scrollToTopID: UUID = UUID()
    
    init(scrollToTopID: UUID = UUID()) {
        self.scrollToTopID = scrollToTopID
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }
    
    var completedAchievements: Int {
        ["constance", "semaine_sobre", "sleep_hydrated", "heatwave",
         "perfect_week", "iron_month", "centurion",
         "marathonien", "indestructible", "centurion_sobre",
         "legende", "aqua_addict", "dry_january", "sober_october",
         "no_alcohol_november", "summer_hydration"]
            .filter { HealthDataManager.shared.isAchievementCompleted($0) }.count
    }
    
    var completedChallenges: Int {
        ["matinal", "regulier", "grand_buveur", "active_day",
         "soiree_tranquille", "cadence_parfaite", "grand_ecart",
         "flash_hydrate", "recuperation", "matin_champion"]
            .filter { HealthDataManager.shared.isChallengeCompleted($0) }.count
    }
    
    // MARK: - Badges
    
    private var allBadges: [(id: String, sfSymbol: String, color: Color, title: String, isPro: Bool)] {
        [
            ("drop", "drop.fill", Color(hex: "4DA8F5"), "Drop", false),
            ("wave", "waveform.path.ecg", Color(hex: "10B981"), "Wave", false),
            ("flame", "flame.fill", Color.orange, "Flame", false),
            ("leaf", "leaf.fill", Color.green, "Leaf", false),
            ("star", "star.fill", Color.yellow, "Star", false),
            ("bolt", "bolt.fill", Color(hex: "F59E0B"), "Bolt", false),
            ("crown", "crown.fill", Color.purple, "Crown", true),
            ("diamond", "diamond.fill", Color.cyan, "Diamond", true),
            ("heart", "heart.fill", Color.red, "Heart", true),
            ("moon", "moon.stars.fill", Color.indigo, "Moon", true),
            ("sun", "sun.max.fill", Color.orange, "Sun", false),
            ("cloud", "cloud.sun.fill", Color(hex: "4DA8F5"), "Cloud", false),
        ]
    }
    
    private var unlockedBadgeIDs: Set<String> {
        var unlocked: Set<String> = ["drop", "wave", "flame", "leaf", "star", "bolt", "sun", "cloud"]
        if completedAchievements >= 4 { unlocked.insert("crown") }
        if completedAchievements >= 8 { unlocked.insert("diamond") }
        if completedAchievements >= 12 { unlocked.insert("heart") }
        if completedAchievements >= 16 { unlocked.insert("moon") }
        return unlocked
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        Color.clear.frame(height: 0).id("top")
                        
                        // MARK: Header
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
                        
                        // MARK: Profile Header Card
                        profileHeaderCard
                            .padding(.horizontal)
                        
                        if showBadgePicker {
                            badgePickerSection
                                .padding(.horizontal)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // MARK: Hydration Section
                        hydrationSection
                            .padding(.horizontal)
                        
                        // MARK: Physical Profile Section
                        physicalProfileSection
                            .padding(.horizontal)
                        
                        // MARK: App Info
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
    }
    
    // MARK: - Computed Views
    
    private var profileHeaderCard: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(gradientForBadge(selectedBadgeID))
                        .frame(width: 70, height: 70)
                    Text(healthStore.firstName.prefix(1).uppercased())
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(healthStore.firstName.isEmpty ? "User" : healthStore.firstName)
                            .font(.system(size: 22, weight: .bold))
                        if selectedBadgeID != "" {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Button {
                        showBadgePicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 10))
                            Text("Choose a badge")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(6)
                    }
                }
                
                Spacer()
            }
            
            // Stats
            HStack(spacing: 0) {
                statItem(value: "\(store.currentStreak)", label: "Streak days", color: .orange)
                Divider().frame(height: 40)
                statItem(value: "\(completedAchievements + completedChallenges)", label: "Achievements\n& challenges", color: .blue)
                Divider().frame(height: 40)
                statItem(value: String(format: "%.1f L", store.totalAlcoholLiters), label: "Total drunk", color: .purple)
            }
            .padding(.vertical, 8)
            
            // XP Level
            xpLevelSection
        }
        .padding(20)
        .background(Color("AppCardBackground"))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var xpLevelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Level \(xpManager.currentLevel)")
                        .font(.system(size: 14, weight: .bold))
                    Text("XP Progress")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.blue)
                }
                Spacer()
                Text("\(xpManager.xpInCurrentLevel) / \(xpManager.currentLevelRange) XP")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(UIColor.systemGray5))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: max(0, geo.size.width * (xpManager.progressRatio.isFinite ? xpManager.progressRatio : 0)), height: 8)
                        .animation(.easeInOut(duration: 0.6), value: xpManager.progressRatio)
                }
            }
            .frame(height: 8)
            
            HStack {
                Text("\(xpManager.xpInCurrentLevel) XP accumulated")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(xpManager.xpUntilNextLevel ?? 0) XP left → Next")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
    }
    
    private var badgePickerSection: some View {
        BadgePickerSection(
            allBadges: allBadges,
            selectedBadgeID: $selectedBadgeID,
            isPremiumUser: isPremiumUser,
            unlockedBadgeIDs: unlockedBadgeIDs
        ) {
            withAnimation { showBadgePicker = false }
        }
    }
    
    private var hydrationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "4DA8F5"))
                Text("Hydration")
                    .font(.system(size: 18, weight: .bold))
            }
            
            Button {
                showGoalEditor = true
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "target")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    
                    Text("Daily goal")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(Int(dailyGoalMl)) ml")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.systemGray3))
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var physicalProfileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "9B59B6"))
                Text("Physical profile")
                    .font(.system(size: 18, weight: .bold))
            }
            
            Button {
                showBodyEditor = true
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "scalemass.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.green)
                    }
                    
                    Text("Weight")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(Int(healthStore.weightKg)) kg")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.systemGray3))
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            
            Button {
                showBodyEditor = true
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "ruler")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    
                    Text("Height")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(Int(healthStore.heightCm)) cm")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.systemGray3))
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            
            Button {
                showBodyEditor = true
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "person")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.purple)
                    }
                    
                    Text("Gender")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(genderLabel(healthStore.gender))
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.systemGray3))
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
    }
    
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
    
    // MARK: - Helper Functions
    
    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func gradientForBadge(_ badgeID: String) -> AnyShapeStyle {
        if let badge = allBadges.first(where: { $0.id == badgeID }) {
            return AnyShapeStyle(badge.color)
        }
        return AnyShapeStyle(Color.blue)
    }
    
    private func genderLabel(_ gender: String) -> String {
        switch gender {
        case "male": return "Male"
        case "female": return "Female"
        case "other": return "Other"
        default: return "Not specified"
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
    let storeKit = StoreKitManager()
    let xpManager = XPManager()
    let achievementManager = AchievementManager()
    let challengeManager = ChallengeManager()
    
    return ProfileView()
        .environmentObject(store)
        .environmentObject(storeKit)
        .environmentObject(xpManager)
        .environmentObject(achievementManager)
        .environmentObject(challengeManager)
        .modelContainer(container)
}
