import Foundation
import SwiftData

enum EntryValidation {
    static let maxAmountMl: Double = 5000

    static func isValid(amountMl: Double) -> Bool {
        amountMl.isFinite && amountMl > 0 && amountMl <= maxAmountMl
    }

    static func isValid(timestamp: TimeInterval) -> Bool {
        timestamp.isFinite && timestamp > 0
    }
}

/// Seul point d'accès à SwiftData. Garde en cache les entrées du jour ;
/// tout `save()` réussi vide ce cache.
@MainActor
final class EntryRepository {
    private let context: ModelContext

    private var cachedWater: [WaterEntry]?
    private var cachedAlcohol: [WaterAlcoholEntry]?
    private var cacheDay: Date = .distantPast

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Cache du jour

    func todayWater() -> [WaterEntry] {
        refreshTodayCacheIfNeeded()
        return cachedWater ?? []
    }

    func todayAlcohol() -> [WaterAlcoholEntry] {
        refreshTodayCacheIfNeeded()
        return cachedAlcohol ?? []
    }

    func invalidateTodayCache() {
        cachedWater = nil
        cachedAlcohol = nil
    }

    // Eau et alcool sont rafraîchis ensemble : un seul horodatage de jour pour les deux.
    private func refreshTodayCacheIfNeeded() {
        let (start, end) = Self.dayRange(containing: Date())
        guard cachedWater == nil || cachedAlcohol == nil || cacheDay != start else { return }
        cachedWater = water(from: start, to: end)
        cachedAlcohol = alcohol(from: start, to: end)
        cacheDay = start
    }

    // MARK: - Écriture

    func insert<T: PersistentModel>(_ model: T) { context.insert(model) }
    func delete<T: PersistentModel>(_ model: T) { context.delete(model) }
    func rollback() { context.rollback() }

    @discardableResult
    func save() -> Bool {
        do {
            try context.save()
            invalidateTodayCache()
            return true
        } catch {
            print("⚠️ EntryRepository – échec de la sauvegarde : \(error)")
            return false
        }
    }

    // MARK: - Eau

    func water(from start: Date? = nil, to end: Date? = nil) -> [WaterEntry] {
        var descriptor = FetchDescriptor<WaterEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        if let s = start, let e = end {
            descriptor.predicate = #Predicate { $0.date >= s && $0.date < e }
        } else if let e = end {
            descriptor.predicate = #Predicate { $0.date < e }
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    func allWater() -> [WaterEntry] { water() }

    func totalWaterMl() -> Double? {
        guard let results = try? context.fetch(FetchDescriptor<WaterEntry>()) else { return nil }
        return results.reduce(0.0) { $0 + $1.amountMl }
    }

    func distinctWaterDayCount() -> Int? {
        guard let results = try? context.fetch(FetchDescriptor<WaterEntry>()) else { return nil }
        return Set(results.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    func waterIntentIDs() -> Set<String> {
        Set(allWater().compactMap(\.siriIntentID))
    }

    // MARK: - Alcool

    func alcohol(from start: Date? = nil, to end: Date? = nil) -> [WaterAlcoholEntry] {
        var descriptor = FetchDescriptor<WaterAlcoholEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        if let s = start, let e = end {
            descriptor.predicate = #Predicate { $0.date >= s && $0.date < e }
        } else if let e = end {
            descriptor.predicate = #Predicate { $0.date < e }
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    func allAlcohol() -> [WaterAlcoholEntry] { alcohol() }

    func totalAlcoholMl() -> Double? {
        guard let results = try? context.fetch(FetchDescriptor<WaterAlcoholEntry>()) else { return nil }
        return results.reduce(0.0) { $0 + $1.amountMl }
    }

    func alcoholIntentIDs() -> Set<String> {
        Set(allAlcohol().compactMap(\.siriIntentID))
    }

    // MARK: - DayRecord

    func dayRecord(for day: Date) -> DayRecord? {
        let (start, end) = Self.dayRange(containing: day)
        let descriptor = FetchDescriptor<DayRecord>(predicate: #Predicate { $0.date >= start && $0.date < end })
        return (try? context.fetch(descriptor))?.first
    }

    func dayRecords(since start: Date) -> [DayRecord] {
        let descriptor = FetchDescriptor<DayRecord>(
            predicate: #Predicate { $0.date >= start },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func dayRecords(before cutoff: Date) -> [DayRecord] {
        let descriptor = FetchDescriptor<DayRecord>(predicate: #Predicate { $0.date < cutoff })
        return (try? context.fetch(descriptor)) ?? []
    }

    func allDayRecords() -> [DayRecord] {
        (try? context.fetch(FetchDescriptor<DayRecord>())) ?? []
    }

    // MARK: - Helpers

    static func dayRange(containing date: Date) -> (start: Date, end: Date) {
        let start = Calendar.current.startOfDay(for: date)
        return (start, Calendar.current.date(byAdding: .day, value: 1, to: start)!)
    }
}
