import StoreKit
import SwiftUI
import Combine

// MARK: - StoreKitManager
// Gère les abonnements Premium via StoreKit 2.
// Produits à configurer dans App Store Connect > Monetization > Subscriptions :
//   Groupe : "Premium"
//   - com.AquApp.premium.monthly  (mensuel,  1,99 €) — avec période d'essai gratuite
//   - com.AquApp.premium.yearly   (annuel,  15,99 €)

@MainActor
final class StoreKitManager: ObservableObject {

    // MARK: - Identifiants produits

    static let monthlyID = "com.AquApp.premium.monthly"
    static let yearlyID  = "com.AquApp.premium.yearly"

    static let allProductIDs: Set<String> = [monthlyID, yearlyID]

    // MARK: - État publié

    @Published var products:             [Product] = []
    @Published var isPremiumUser:        Bool      = false
    @Published var isLoading:            Bool      = false
    @Published var errorMessage:         String?   = nil

    /// Libellé de l'essai gratuit du mensuel, ex. "3 jours offerts" (nil si aucun)
    @Published var monthlyTrialDuration: String?   = nil

    private var transactionListener: Task<Void, Error>?

    // MARK: - Init

    init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await refreshPurchaseStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Chargement des produits

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: StoreKitManager.allProductIDs)

            // Ordre garanti : mensuel → annuel
            products = fetched.sorted {
                ($0.id == StoreKitManager.monthlyID) && ($1.id == StoreKitManager.yearlyID)
            }

            // Détecte l'essai gratuit sur le produit mensuel
            if let monthly = products.first(where: { $0.id == StoreKitManager.monthlyID }),
               let subscription = monthly.subscription,
               let offer = subscription.introductoryOffer,
               offer.paymentMode == .freeTrial {
                monthlyTrialDuration = formatTrialPeriod(offer.period)
            }

        } catch {
            print("⚠️ StoreKit – loadProducts : \(error.localizedDescription)")
        }
    }

    // MARK: - Achat

    func purchase(_ product: Product) async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePremiumStatus(for: transaction)
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                errorMessage = String(localized: "storekit.purchase_pending")
            @unknown default:
                break
            }
        } catch {
            errorMessage = String(localized: "storekit.purchase_failed")
            print("⚠️ StoreKit – purchase : \(error)")
        }
    }

    // MARK: - Restauration des achats

    func restorePurchases() async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshPurchaseStatus()
            if !isPremiumUser {
                errorMessage = String(localized: "storekit.no_subscription")
            }
        } catch {
            errorMessage = String(localized: "storekit.restore_failed")
            print("⚠️ StoreKit – restore : \(error)")
        }
    }

    // MARK: - Statut Premium

    func refreshPurchaseStatus() async {
        var active = false
        for await result in StoreKit.Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if StoreKitManager.allProductIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                // Vérifie l'expiration pour les abonnements
                if let expirationDate = transaction.expirationDate {
                    if expirationDate > Date() { active = true; break }
                } else {
                    active = true; break
                }
            }
        }
        isPremiumUser = active
        UserDefaults.standard.set(active, forKey: "isPremiumUser")
    }

    // MARK: - Écoute des transactions en temps réel

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached(priority: .background) { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self else { break }
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePremiumStatus(for: transaction)
                    await transaction.finish()
                } catch {
                    print("⚠️ StoreKit – transaction update invalide : \(error)")
                }
            }
        }
    }

    // MARK: - Helpers

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):  return value
        case .unverified(_, let e): throw e
        }
    }

    private func updatePremiumStatus(for transaction: StoreKit.Transaction) async {
        var active = false
        if StoreKitManager.allProductIDs.contains(transaction.productID),
           transaction.revocationDate == nil {
            if let expirationDate = transaction.expirationDate {
                active = expirationDate > Date()
            } else {
                active = true
            }
        }
        isPremiumUser = active
        UserDefaults.standard.set(active, forKey: "isPremiumUser")
    }

    /// Formate la période d'essai en texte lisible (ex. "7 jours offerts")
    private func formatTrialPeriod(_ period: Product.SubscriptionPeriod) -> String {
        let value = period.value
        switch period.unit {
        case .day:   return String(format: String(localized: "storekit.trial.days"),   value)
        case .week:  return String(format: String(localized: "storekit.trial.weeks"),  value)
        case .month: return String(format: String(localized: "storekit.trial.months"), value)
        case .year:  return String(format: String(localized: "storekit.trial.years"),  value)
        @unknown default: return String(localized: "storekit.free_trial_default")
        }
    }

    // MARK: - Produit par ID (helper vue)

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    var monthlyProduct: Product? { product(for: StoreKitManager.monthlyID) }
    var yearlyProduct:  Product? { product(for: StoreKitManager.yearlyID)  }
}
