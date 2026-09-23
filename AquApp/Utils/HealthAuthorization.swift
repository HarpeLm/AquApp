import HealthKit

/// Seul endroit qui demande l'accès à Apple Santé. Toute nouvelle donnée lue ou
/// écrite doit être ajoutée ici ET décrite dans NSHealthShareUsageDescription /
/// NSHealthUpdateUsageDescription (InfoPlist.xcstrings), sinon App Review refuse.
///
/// iOS ne dit jamais si une LECTURE a été accordée : un refus renvoie simplement
/// des requêtes vides. Ne pas tester `authorizationStatus(for:)` avant de lire —
/// ce statut ne concerne que l'écriture.
enum HealthAuthorization {
    static let offeredKey = "health_permission_offered"

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Eau bue dans AquApp → Santé.
    static let shareTypes: Set<HKSampleType> = [
        HKQuantityType(.dietaryWater),
    ]

    /// Pas : défi « Journée active », succès « Marathonien ».
    /// Entraînements : défi « Récupération ».
    /// Sommeil + eau : succès « Sommeil hydraté » (eau bue avant le coucher).
    static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.stepCount),
        HKObjectType.workoutType(),
        HKCategoryType(.sleepAnalysis),
        HKQuantityType(.dietaryWater),
    ]

    /// Vrai tant qu'au moins un type n'a jamais été proposé à l'utilisateur.
    static func needsRequest() async -> Bool {
        guard isAvailable else { return false }
        let status = try? await HKHealthStore().statusForAuthorizationRequest(toShare: shareTypes, read: readTypes)
        return status == .shouldRequest
    }

    static func request() async {
        guard isAvailable else { return }
        try? await HKHealthStore().requestAuthorization(toShare: shareTypes, read: readTypes)
    }
}
