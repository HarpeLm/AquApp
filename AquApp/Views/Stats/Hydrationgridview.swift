import SwiftUI
import SwiftData

// MARK: - HydrationGridView (calendrier mensuel)
// Une section par mois ; chaque mois contient EXACTEMENT autant de
// cases que de jours (28/30/31), alignées sur les jours de semaine.

struct HydrationGridView: View {
    @EnvironmentObject var store: AppDataStore

    @State private var ratios: [Date: Double] = [:]

    private let calendar = Calendar.current
    private let columns  = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    /// 12 derniers mois, du plus récent au plus ancien
    private var months: [Date] {
        let today = calendar.startOfDay(for: Date())
        guard let firstOfCurrent = calendar.date(
            from: calendar.dateComponents([.year, .month], from: today)
        ) else { return [] }
        return (0..<12).compactMap {
            calendar.date(byAdding: .month, value: -$0, to: firstOfCurrent)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(months, id: \.self) { month in
                monthSection(month)
            }
            legend
        }
        .padding(20)
        .background(Color.black)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
        .onAppear { ratios = store.contributionRatios(days: 365) }
        .onChange(of: store.todayWaterMl) { _, _ in
            ratios = store.contributionRatios(days: 365)
        }
    }

    // MARK: - Section mois

    @ViewBuilder
    private func monthSection(_ month: Date) -> some View {
        let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        let reached     = reachedCount(in: month, days: daysInMonth)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(month.formatted(.dateTime.month(.wide).year()).capitalized)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(reached)/\(daysInMonth)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Initiales des jours de semaine (alignées sur firstWeekday)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    Text(weekdaySymbols[i])
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45))
                }
            }

            // Autant de cases que de jours dans le mois
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<leadingEmptyCells(for: month), id: \.self) { _ in
                    Color.clear.frame(height: 14)
                }
                ForEach(1...daysInMonth, id: \.self) { day in
                    cell(day: day, month: month)
                }
            }
        }
    }

    // MARK: - Cellule jour

    private func cell(day: Int, month: Date) -> some View {
        let date     = calendar.date(byAdding: .day, value: day - 1, to: month)!
        let isFuture = date > calendar.startOfDay(for: Date())
        let ratio    = ratios[date] ?? 0

        return RoundedRectangle(cornerRadius: 3)
            .fill(color(for: ratio))
            .frame(height: 14)
            .opacity(isFuture ? 0.12 : 1.0)
            .accessibilityLabel("\(day) \(month.formatted(.dateTime.month(.wide)))")
            .accessibilityValue("\(Int(ratio * 100)) %")
    }

    private func color(for ratio: Double) -> Color {
        switch ratio {
        case ..<0.01: return Color.white.opacity(0.08)
        case ..<0.34: return Color(hex: "185FA5").opacity(0.45)
        case ..<0.67: return Color(hex: "2B87E8").opacity(0.70)
        case ..<1.00: return Color(hex: "4DA8F5").opacity(0.90)
        default:      return Color(hex: "4DA8F5")
        }
    }

    // MARK: - Helpers calendrier

    /// Cases vides avant le 1er du mois (alignement lundi/dimanche selon locale)
    private func leadingEmptyCells(for month: Date) -> Int {
        guard let first = calendar.date(
            from: calendar.dateComponents([.year, .month], from: month)
        ) else { return 0 }
        let weekday      = calendar.component(.weekday, from: first)   // 1 = dimanche
        let firstWeekday = calendar.firstWeekday                        // FR = 2 (lundi)
        return (weekday - firstWeekday + 7) % 7
    }

    /// Initiales des jours de semaine ordonnées selon firstWeekday
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols   // index 0 = dimanche
        let fw      = calendar.firstWeekday
        var out: [String] = []
        for i in 0..<7 { out.append(symbols[(fw - 1 + i) % 7]) }
        return out
    }

    /// Nombre de jours avec objectif atteint dans le mois
    private func reachedCount(in month: Date, days: Int) -> Int {
        (1...days).reduce(0) { acc, day in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: month) else {
                return acc
            }
            return acc + ((ratios[date] ?? 0) >= 1.0 ? 1 : 0)
        }
    }

    // MARK: - Légende

    private var legend: some View {
        HStack(spacing: 6) {
            Text(String(localized: "stats.grid.less"))
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(legendColor(i))
                    .frame(width: 10, height: 10)
            }
            Text(String(localized: "stats.grid.more"))
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(.white.opacity(0.6))
    }

    private func legendColor(_ i: Int) -> Color {
        switch i {
        case 0:  return Color.white.opacity(0.08)
        case 1:  return Color(hex: "185FA5").opacity(0.45)
        case 2:  return Color(hex: "2B87E8").opacity(0.70)
        case 3:  return Color(hex: "4DA8F5").opacity(0.90)
        default: return Color(hex: "4DA8F5")
        }
    }
}

// MARK: - Preview

#Preview {
    let config    = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
        configurations: config
    )
    let store = AppDataStore(modelContext: container.mainContext)
    return HydrationGridView()
        .environmentObject(store)
        .padding()
}
