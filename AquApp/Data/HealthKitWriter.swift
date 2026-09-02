//
//  HealthKitWriter.swift
//  AquApp
//
//  Created by Fabian Dargaud on 18/05/2026.
//
import HealthKit
import Foundation

// MARK: - HealthKitWriter
//
// Responsabilité unique : écrire et supprimer les échantillons HKQuantityType
// dietaryWater dans Apple Health, en miroir des WaterEntry de SwiftData.
//
// Stratégie de synchronisation :
//   • Chaque WaterEntry possède un UUID stable (entry.id).
//   • Cet UUID est stocké dans les métadonnées HK sous la clé "AquAppEntryID".
//   • À la suppression, on retrouve l'échantillon HK par cette clé et on
//     l'efface — pas de doublon, pas de dérive entre SwiftData et Health.
//
// Autorisation :
//   • requestWriteAuthorizationIfNeeded() est appelé une fois au lancement
//     depuis AquAppApp.init(), avant toute écriture.
//   • Toutes les opérations sont silencieuses en cas de refus — l'app
//     fonctionne normalement, Health reste simplement non synchronisé.
//
// Thread-safety :
//   • Toutes les méthodes publiques sont nonisolated et s'exécutent sur un
//     thread HK background via Task.detached. Aucun blocage du MainActor.

final class HealthKitWriter {

    static let shared = HealthKitWriter()
    private init() {}

    // Clé de métadonnée qui lie un échantillon HK à son WaterEntry SwiftData
    private static let entryIDMetadataKey = "AquAppEntryID"

    private let healthStore = HKHealthStore()
    private let waterType   = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!

    // MARK: - Autorisation

    /// Demande la permission d'écriture pour dietaryWater.
    /// Idempotent — sans effet si déjà accordée ou refusée.
    /// À appeler une seule fois au lancement (AquAppApp.init).
    func requestWriteAuthorizationIfNeeded() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        healthStore.requestAuthorization(toShare: [waterType], read: []) { _, _ in
            // Résultat ignoré — les écritures vérifient le statut elles-mêmes
        }
    }

    // MARK: - Écriture

    /// Écrit un échantillon dietaryWater dans Health pour une WaterEntry.
    /// Sans effet si HealthKit n'est pas disponible ou si l'écriture est refusée.
    ///
    /// - Parameters:
    ///   - amountMl: Volume en millilitres à écrire.
    ///   - date:     Date de l'entrée (identique à WaterEntry.date).
    ///   - entryID:  UUID de la WaterEntry — stocké en métadonnée pour
    ///               permettre la suppression précise ultérieure.
    func write(amountMl: Double, date: Date, entryID: UUID) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard authorizationStatus == .sharingAuthorized else { return }

        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: amountMl)
        let sample   = HKQuantitySample(
            type:     waterType,
            quantity: quantity,
            start:    date,
            end:      date,
            metadata: [HealthKitWriter.entryIDMetadataKey: entryID.uuidString]
        )

        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            do {
                try await self.healthStore.save(sample)
            } catch {
                // Échec silencieux — pas critique pour l'UX
                print("⚠️ HealthKitWriter – write failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Suppression

    /// Supprime dans Health l'échantillon correspondant à une WaterEntry.
    /// Retrouve l'échantillon via son AquAppEntryID en métadonnée.
    ///
    /// - Parameters:
    ///   - entryID: UUID de la WaterEntry à supprimer.
    ///   - date:    Date approximative de l'entrée — sert à réduire la plage
    ///              de recherche HK (±1 seconde autour de la date exacte).
    func delete(entryID: UUID, date: Date) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard authorizationStatus == .sharingAuthorized else { return }

        // Prédicat combiné : plage temporelle ±30 minutes + metadata UUID
        // La plage large compense d'éventuelles légères dérives de date entre
        // le moment d'enregistrement SwiftData et le sample HK.
        let windowStart = date.addingTimeInterval(-1800)  // -30 min
        let windowEnd   = date.addingTimeInterval(1800)   // +30 min
        let timePredicate = HKQuery.predicateForSamples(
            withStart: windowStart,
            end:       windowEnd,
            options:   .strictStartDate
        )
        let metaPredicate = HKQuery.predicateForObjects(
            withMetadataKey: HealthKitWriter.entryIDMetadataKey,
            allowedValues:   [entryID.uuidString]
        )
        let predicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [timePredicate, metaPredicate]
        )

        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            do {
                let samples = try await self.fetchSamples(predicate: predicate)
                guard !samples.isEmpty else { return }
                try await self.healthStore.delete(samples)
            } catch {
                print("⚠️ HealthKitWriter – delete failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers privés

    private var authorizationStatus: HKAuthorizationStatus {
        healthStore.authorizationStatus(for: waterType)
    }

    /// Fetch async des échantillons HK correspondant au prédicat.
    private func fetchSamples(predicate: NSPredicate) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType:       waterType,
                predicate:        predicate,
                limit:            HKObjectQueryNoLimit,
                sortDescriptors:  nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            self.healthStore.execute(query)
        }
    }
}
