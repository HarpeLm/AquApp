//
//  HydrationHistoryView.swift
//  AquApp
//
//  Created by Fabian Dargaud on 10/09/2026.
//

import SwiftUI
import SwiftData

struct HydrationHistoryView: View {
    @EnvironmentObject var store: AppDataStore

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var ratios: [Date: Double] = [:]

    private let calendar  = Calendar.current
    private let cellSize: CGFloat = 11
    private let spacing:  CGFloat = 3
    private let monthGap: CGFloat = 14

    private var yearRange: (start: Date, end: Date) {
        let start = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
        let end   = calendar.date(from: DateComponents(year: selectedYear, month: 12, day: 31))!
        return (start, end)
    }

    private var monthGroups: [(month: Date, columns: [[Date?]])] {
        let (start, end) = yearRange
        var result: [(Date, [[Date?]])] = []
        var month = start

        while month <= end {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: month)!
            var columns: [[Date?]] = []
            var weekStart = calendar.dateInterval(of: .weekOfYear, for: month)!.start

            while weekStart < nextMonth && weekStart <= end {
                var col: [Date?] = []
                for offset in 0..<7 {
                    let day = calendar.date(byAdding: .day, value: offset, to: weekStart)!
                    let inMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
                    col.append(inMonth ? day : nil)
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

    private var previousYearStats: (reachedDays: Int, percentage: Double)? {
        let previousYear = selectedYear - 1
        guard yearsRange.contains(previousYear) else { return nil }

        let start = calendar.date(from: DateComponents(year: previousYear, month: 1, day: 1))!
        let end   = calendar.date(from: DateComponents(year: previousYear, month: 12, day: 31))!
        
        let allRatios = store.contributionRatios(days: 4000)
        let prevRatios = allRatios.filter { $0.key >= start && $0.key <= end }

        let reachedDays = prevRatios.values.filter { $0 >= 1.0 }.count
        let totalDays = calendar.range(of: .day, in: .year, for: start)?.count ?? 365
        let percentage = Double(reachedDays) / Double(totalDays)

        return (reachedDays, percentage)
    }

    private var comparisonText: String {
        if let prevStats = previousYearStats {
            let currentTotalDays = calendar.range(of: .day, in: .year, for: yearRange.start)?.count ?? 365
            let currentPercentage = Double(reachedTotal) / Double(currentTotalDays)
            
            let diff = (currentPercentage - prevStats.percentage) * 100
            let sign = diff > 0 ? "+" : ""
            
            return String(format: String(localized: "stats.history.vs"),
                          "\(selectedYear - 1)", "\(sign)\(Int(abs(diff)))%")
        } else {
            return String(format: String(localized: "stats.history.days_reached"),
                          "\(reachedTotal)")
        }
    }

    private var comparisonIconColor: Color {
        if previousYearStats != nil {
            return comparisonText.contains("+") ? .green : .red
        }
        return .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Sélecteur d'année
            HStack {
                Text(String(localized: "stats.history.year"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Picker(String(localized: "stats.history.year"), selection: $selectedYear) {
                    ForEach(yearsRange, id: \.self) { year in
                        Text(verbatim: "\(year)").tag(year)
                    }
                }
                .pickerStyle(.menu)
                .tint(.accentColor)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            // Compteur + Comparaison
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(localized: "stats.grid.title"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(reachedTotal)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                }

                HStack {
                    Image(systemName: previousYearStats != nil ? "arrow.up.arrow.down" : "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(comparisonIconColor)
                    Text(comparisonText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 24)

            // Grille horizontale avec scroll
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: monthGap) {
                        ForEach(monthGroups, id: \.month) { group in
                            monthBlock(group.month, columns: group.columns)
                                .id(group.month)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 24)
                }
                .onAppear {
                    if let last = monthGroups.last?.month {
                        proxy.scrollTo(last, anchor: .trailing)
                    }
                }
                .onChange(of: selectedYear) { _, _ in
                    if let last = monthGroups.last?.month {
                        proxy.scrollTo(last, anchor: .trailing)
                    }
                }
            }

            // Légende
            legend
                .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .background(Color("AppBackground"))
        .onAppear { ratios = store.contributionRatios(days: 4000) }
        .onChange(of: selectedYear) { _, _ in
            ratios = store.contributionRatios(days: 4000)
        }
    }

    private func monthBlock(_ month: Date, columns: [[Date?]]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(month.formatted(.dateTime.month(.abbreviated)))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.bottom, 2)

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

    private func cell(for date: Date) -> some View {
        let isFuture = date > calendar.startOfDay(for: Date())
        let ratio    = ratios[date] ?? 0
        return RoundedRectangle(cornerRadius: 2)
            .fill(color(for: ratio))
            .frame(width: cellSize, height: cellSize)
            .opacity(isFuture ? 0.12 : 1.0)
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
        .foregroundColor(.secondary)
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

    private var yearsRange: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        let launchYear  = Calendar.current.component(.year, from: store.firstLaunchDate)
        return Array(launchYear...currentYear).reversed()
    }
}

#Preview {
    let config    = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
        configurations: config
    )
    let store = AppDataStore(modelContext: container.mainContext)
    return HydrationHistoryView()
        .environmentObject(store)
}
