import SwiftUI
import SwiftData

// MARK: - HomeView

struct HomeView: View {
    @ObservedObject private var healthStore = HealthDataManager.shared
    private var userName: String { healthStore.firstName }
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var confettiManager: ConfettiManager
    @EnvironmentObject var weatherManager: WeatherManager

    @Binding var openAddWater: Bool
    var scrollToTopID: UUID

    @State private var showAddWater = false
    @State private var showAddAlcool = false
    @State private var pendingConfettiEvent: ConfettiEvent? = nil

    init(openAddWater: Binding<Bool> = .constant(false), scrollToTopID: UUID = UUID()) {
        self._openAddWater = openAddWater
        self.scrollToTopID = scrollToTopID
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Color.clear.frame(height: 0).id("top")

                        // MARK: Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.homeGoodMorning)
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                Text(userName)
                                    .font(.system(size: 32, weight: .bold))
                                Image(systemName: "hand.wave.fill")
                                    .accessibilityHidden(true)
                                    .font(.system(size: 28))
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // MARK: Bannière canicule
                        if weatherManager.isHeatwave, let adapted = weatherManager.adaptedGoalMl {
                            HeatwaveBanner(
                                tempC: weatherManager.currentTemperatureC ?? 32,
                                adaptedMl: adapted
                            )
                            .padding(.horizontal)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // MARK: Carte progression
                        ProgressCard(
                            current: store.todayWaterMl,
                            goal: store.effectiveGoalMl,
                            progress: store.todayProgress,
                            percent: Int(store.todayProgress * 100),
                            compensation: store.todayAlcoholCompensationMl
                        )
                        .padding(.horizontal)

                        // MARK: Boutons d'action
                        HStack(spacing: 12) {
                            ActionButton(
                                label: L10n.homeAddWater,
                                sfSymbol: "drop.fill",
                                gradient: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")]
                            ) { showAddWater = true }

                            ActionButton(
                                label: L10n.homeAddAlcohol,
                                sfSymbol: "wineglass.fill",
                                gradient: [Color(hex: "9B59B6"), Color(hex: "6C3483")]
                            ) { showAddAlcool = true }
                        }
                        .padding(.horizontal)

                        // MARK: Stats rapides
                        HStack(spacing: 12) {
                            StatCard(
                                sfSymbol: "flame.fill",
                                symbolColor: .orange,
                                label: L10n.homeStreakLabel,
                                value: "\(store.currentStreak)",
                                unit: L10n.homeDays
                            )
                            StatCard(
                                sfSymbol: "leaf.fill",
                                symbolColor: .green,
                                label: L10n.homeSoberLabel,
                                value: "\(store.soberDaysStreak)",
                                unit: L10n.homeDays
                            )
                        }
                        .padding(.horizontal)

                        // MARK: Activité récente
                        RecentActivitySection(
                            waterEntries: store.todayWaterEntries(),
                            alcoholEntries: store.todayAlcoholEntries()
                        ) { entry in
                            store.deleteWater(entry)
                        } onDeleteAlcohol: { entry in
                            store.deleteAlcohol(entry)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 32)
                }
                .background(Color("AppBackground"))
                .navigationBarHidden(true)
                .onChange(of: scrollToTopID) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("top") }
                }
            }
            .sheet(isPresented: $showAddWater) {
                AddWaterSheet(
                    isPresented: $showAddWater,
                    onGoalReached: {
                        pendingConfettiEvent = .goalReached
                    }
                )
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
            }
            .sheet(isPresented: $showAddAlcool) {
                AddAlcoolSheet(isPresented: $showAddAlcool)
                    .environmentObject(store)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.hidden)
            }
            .onChange(of: showAddWater) { _, isShowing in
                if !isShowing, let event = pendingConfettiEvent {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        confettiManager.trigger(event)
                    }
                    pendingConfettiEvent = nil
                }
            }
            .onChange(of: openAddWater) { _, shouldOpen in
                if shouldOpen {
                    showAddWater = true
                    openAddWater = false
                }
            }
        }
    }
}

// MARK: - Bannière canicule

struct HeatwaveBanner: View {
    let tempC: Double
    let adaptedMl: Double

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "thermometer.sun.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.heatwaveBannerTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Text(String(format: L10n.heatwaveBannerBody, UnitFormatter.volume(adaptedMl)))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(String(format: String(localized: "heatwave.temp_label"), Int(tempC)))
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.orange)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.heatwaveBannerTitle)
        .accessibilityValue(String(format: L10n.heatwaveBannerBody, UnitFormatter.volume(adaptedMl)))
    }
}

// MARK: - Carte de progression

struct ProgressCard: View {
    let current: Double
    let goal: Double
    let progress: Double
    let percent: Int
    var compensation: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color(hex: "E3EFFC"), lineWidth: 14)
                    .frame(width: 160, height: 160)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 160, height: 160)
                    .animation(.easeInOut(duration: 0.6), value: progress)
                VStack(spacing: 4) {
                    Text("\(percent)%")
                        .font(.system(size: 36, weight: .bold))
                    Text("\(UnitFormatter.volumeNumber(current)) / \(UnitFormatter.volume(goal))")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "accessibility.hydration_progress_label"))
            .accessibilityValue(String(format: String(localized: "accessibility.hydration_value"), percent, Int(current), Int(goal)))

            VStack(alignment: .trailing, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: "E3EFFC"))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(
                                colors: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: max(0, geo.size.width * (progress.isFinite ? progress : 0)), height: 8)
                            .animation(.easeInOut(duration: 0.6), value: progress)
                    }
                }
                .frame(height: 8)
                .accessibilityHidden(true)

                Text(String(format: String(localized: "progress.goal_label"), Int(goal)))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                if compensation > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "wineglass.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                            .accessibilityHidden(true)
                        Text(String(format: String(localized: "progress.alcohol_compensation"), Int(compensation)))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .padding(24)
        .background(Color("AppCardBackground"))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.3), value: compensation)
    }
}

// MARK: - Bouton d'action

struct ActionButton: View {
    let label: String
    let sfSymbol: String
    let gradient: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: sfSymbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(LinearGradient(
                colors: gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .cornerRadius(16)
        }
        .accessibilityLabel(String(format: String(localized: "accessibility.add_label"), label))
        .accessibilityHint(String(localized: "accessibility.add_hint"))
    }
}

// MARK: - Carte statistique

struct StatCard: View {
    let sfSymbol: String
    let symbolColor: Color
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(symbolColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: sfSymbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(symbolColor)
                    .accessibilityHidden(true)
            }
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(unit)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .minimumScaleFactor(0.8)
            }
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("AppCardBackground"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value) \(unit)")
    }
}

// MARK: - SwipeToDeleteView
struct SwipeToDeleteView<Content: View>: View {
    let content: Content
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0

    init(@ViewBuilder content: () -> Content, onDelete: @escaping () -> Void) {
        self.content = content()
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Fond neutre révélé par le swipe (icône poubelle rouge conservée)
            Rectangle()
                .fill(Color("AppCardBackground"))
                .frame(height: 50)
                .overlay(
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.leading, 24)
                        .opacity(offset < -40 ? 1 : 0)
                )
                .cornerRadius(16)
                .padding(.horizontal, 16)

            content
                .contentShape(Rectangle())
                .offset(x: offset)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 15, coordinateSpace: .local)
                        .onChanged { value in
                            // Ne réagit qu'aux gestes majoritairement horizontaux,
                            // pour laisser le ScrollView parent gérer le scroll vertical.
                            guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                            if value.translation.width < 0 {
                                offset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else {
                                withAnimation(.spring()) { offset = 0 }
                                return
                            }
                            if value.translation.width < -80 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    offset = -UIScreen.main.bounds.width
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onDelete()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        offset = 0
                                    }
                                }
                            } else {
                                withAnimation(.spring()) {
                                    offset = 0
                                }
                            }
                        }
                )
        }
    }
}

// MARK: - Activité récente
struct RecentActivitySection: View {
    let waterEntries: [WaterEntry]
    let alcoholEntries: [WaterAlcoholEntry]
    let onDeleteWater: (WaterEntry) -> Void
    let onDeleteAlcohol: (WaterAlcoholEntry) -> Void

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "HH:mm"
        return f
    }()

    private var items: [ActivityItem] {
        let water = waterEntries.map {
            ActivityItem(
                id: $0.id.uuidString,
                label: String(format: String(localized: "activity.water_entry"), Int($0.amountMl)),
                time: timeFormatter.string(from: $0.date),
                date: $0.date,
                kind: .water($0)
            )
        }
        let alcohol = alcoholEntries.map {
            ActivityItem(
                id: $0.id.uuidString,
                label: "\(UnitFormatter.volume($0.amountMl)) \($0.alcoholType.localizedName)",
                time: timeFormatter.string(from: $0.date),
                date: $0.date,
                kind: .alcohol($0)
            )
        }
        return (water + alcohol).sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.homeRecentActivity)
                .font(.system(size: 20, weight: .bold))

            if items.isEmpty {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "EEF4FF"))
                            .frame(width: 56, height: 56)
                        Image(systemName: "drop")
                            .accessibilityHidden(true)
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "4DA8F5"))
                    }
                    Text(L10n.homeNoActivity)
                        .font(.system(size: 15, weight: .semibold))
                    Text(L10n.homeNoActivitySub)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color("AppCardBackground"))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        SwipeToDeleteView {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(item.isWater ? Color(hex: "EEF4FF") : Color(hex: "F3E5F5"))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: item.isWater ? "drop.fill" : "wineglass.fill")
                                        .accessibilityHidden(true)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(item.isWater ? Color(hex: "4DA8F5") : Color(hex: "8B5CF6"))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.label)
                                        .font(.system(size: 15, weight: .semibold))
                                    Text(item.time)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button {
                                    switch item.kind {
                                    case .water(let e): onDeleteWater(e)
                                    case .alcohol(let e): onDeleteAlcohol(e)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13))
                                        .foregroundColor(.red.opacity(0.6))
                                        .padding(8)
                                }
                                .accessibilityLabel(String(format: String(localized: "accessibility.delete_entry"), item.label))
                                .accessibilityHint(String(localized: "accessibility.delete_hint"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        } onDelete: {
                            switch item.kind {
                            case .water(let e): onDeleteWater(e)
                            case .alcohol(let e): onDeleteAlcohol(e)
                            }
                            HapticManager.shared.entryDeleted()
                        }

                        if index < items.count - 1 {
                            Divider().padding(.leading, 72)
                        }
                    }
                }
                .background(Color("AppCardBackground"))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
        }
    }
}

// MARK: - ActivityItem
private struct ActivityItem {
    let id: String
    let label: String
    let time: String
    let date: Date
    let kind: ActivityKind

    var isWater: Bool {
        if case .water = kind { return true }
        return false
    }
}

private enum ActivityKind {
    case water(WaterEntry)
    case alcohol(WaterAlcoholEntry)
}

// MARK: - Preview
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
        configurations: config
    )
    let store = AppDataStore(modelContext: container.mainContext)
    let confettiManager = ConfettiManager()
    let weatherManager = WeatherManager(store: store)
    HomeView()
        .environmentObject(store)
        .environmentObject(confettiManager)
        .environmentObject(weatherManager)
        .modelContainer(container)
}
