import SwiftUI
import SwiftData

// MARK: - HydrationGridView
// Grille contribution horizontale, petits carreaux, groupée PAR MOIS (12 derniers mois).
// Bouton "Voir tout" : ouvre un sheet avec sélecteur d'année.

struct HydrationGridView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var ratios: [Date: Double] = [:]
    @State private var showHistorySheet = false

    private let calendar  = Calendar.current
    private let cellSize: CGFloat = 11
    private let spacing:  CGFloat = 3
    private let monthGap: CGFloat = 14

    // MARK: - Plage & groupes par mois (12 derniers mois)

    private var dayRange: (start: Date, end: Date) {
        let today = calendar.startOfDay(for: Date())
        let firstOfCurrent = calendar.date(
            from: calendar.dateComponents([.year, .month], from: today)
        )!
        let start = calendar.date(byAdding: .month, value: -11, to: firstOfCurrent)!
        let end = calendar.date(
            byAdding: .day, value: -1,
            to: calendar.date(byAdding: .month, value: 1, to: firstOfCurrent)!
        )!
        return (start, end)
    }

    private var monthGroups: [(month: Date, columns: [[Date?]])] {
        let (start, end) = dayRange
        var result: [(Date, [[Date?]])] = []
        var month = calendar.date(
            from: calendar.dateComponents([.year, .month], from: start)
        )!

        while month <= end {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: month)!
            var columns: [[Date?]] = []
            var weekStart = calendar.dateInterval(of: .weekOfYear, for: month)!.start

            while weekStart < nextMonth && weekStart <= end {
                var col: [Date?] = []
                for offset in 0..<7 {
                    let day = calendar.date(byAdding: .day, value: offset, to: weekStart)!
                    let inRange = day >= start && day <= end
                    let inMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
                    col.append(inRange && inMonth ? day : nil)
                }
                columns.append(col)
                weekStart = calendar.date(byAdding: .day, value: 7, to: weekStart)!
            }

            result.append((month, columns))
            month = nextMonth
        }
        return result
    }

    private var reachedTotal: Int {
        ratios.values.filter { $0 >= 1.0 }.count
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(String(localized: "stats.grid.title"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(reachedTotal)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))

                Spacer()

                // ── Bouton "Voir tout" → ouvre le sheet ───────────────────
                Button {
                    showHistorySheet = true
                } label: {
                    Text(String(localized: "stats.grid.see_all"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.14))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "stats.grid.see_all"))
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: monthGap) {
                        ForEach(monthGroups, id: \.month) { group in
                            monthBlock(group.month, columns: group.columns)
                                .id(group.month)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onAppear {
                    if let last = monthGroups.last?.month {
                        proxy.scrollTo(last, anchor: .trailing)
                    }
                }
            }

            legend
        }
        .padding(20)
        .background(Color.black)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
        .onAppear { ratios = store.contributionRatios(days: 400) }
        .onChange(of: store.todayWaterMl) { _, _ in
            ratios = store.contributionRatios(days: 400)
        }
        // ── Sheet avec detents contrôlés ─────────────────────────────────
        .sheet(isPresented: $showHistorySheet) {
            HydrationHistoryView()
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Bloc mois (en-tête + semaines)

    private func monthBlock(_ month: Date, columns: [[Date?]]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(month.formatted(.dateTime.month(.abbreviated).year(.twoDigits)))
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.75))
                .padding(.bottom, 1)

            HStack(alignment: .top, spacing: spacing) {
                ForEach(columns.indices, id: \.self) { c in
                    VStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { i in
                            if let date = columns[c][i] {
                                cell(for: date)
                            } else {
                                Color.clear.frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Case jour

    private func cell(for date: Date) -> some View {
        let isFuture = date > calendar.startOfDay(for: Date())
        let ratio    = ratios[date] ?? 0
        return RoundedRectangle(cornerRadius: 2)
            .fill(color(for: ratio))
            .frame(width: cellSize, height: cellSize)
            .opacity(isFuture ? 0.12 : 1.0)
            .accessibilityLabel(date.formatted(.dateTime.day().month()))
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
