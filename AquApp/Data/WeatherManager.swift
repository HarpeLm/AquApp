import Foundation
import CoreLocation
import UserNotifications
import SwiftUI
import Combine
import WeatherKit


// MARK: - WeatherManager
// 1. Géolocalisation (CoreLocation)
// 2. La detection de la température se fait mainteant par WeatherKit vu que l'on propose un application payante
// 3. Détection canicule (≥ 32°C)
// 4. Objectif adaptatif selon la chaleur (+200ml/degré au-dessus de 32°C)
// 5. Notification canicule unique par jour

final class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var currentTemperatureC: Double? = nil
    @Published var isHeatwave:          Bool    = false
    @Published var adaptedGoalMl:       Double? = nil

    private let locationManager    = CLLocationManager()
    private var lastNotifDate:     Date? = nil
    private weak var store:        AppDataStore?
    private let heatwaveThreshold: Double = 32.0

    init(store: AppDataStore) {
        self.store = store
        super.init()
        locationManager.delegate        = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.distanceFilter  = 5000
    }

    func refresh() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            // Permission refusée ou restreinte — on désactive la bannière canicule
            applyTemperature(nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        fetchTemperature(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Erreur silencieuse — on désactive simplement la fonctionnalité canicule
        applyTemperature(nil)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            // L'utilisateur a refusé — on nettoie l'état canicule
            applyTemperature(nil)
        default:
            break
        }
    }

    // MARK: - Fetch température (WeatherKit)

    /// Arrondi à 2 décimales (~1 km) : suffisant pour la météo, et reste une
    /// « position approximative » au sens d'Apple (fiche de confidentialité, PrivacyInfo).
    static func coarseLocation(latitude lat: Double, longitude lon: Double) -> CLLocation {
        CLLocation(
            latitude:  (lat * 100).rounded() / 100,
            longitude: (lon * 100).rounded() / 100
        )
    }

    private func fetchTemperature(lat: Double, lon: Double) {
        let coarse = Self.coarseLocation(latitude: lat, longitude: lon)

        Task { @MainActor in
            do {
                let current = try await WeatherService.shared.weather(for: coarse, including: .current)
                applyTemperature(current.temperature.converted(to: .celsius).value)
            } catch {
                // Capacité non activée, hors ligne, quota… : on désactive la bannière sans crasher
                applyTemperature(nil)
            }
        }
    }

    // MARK: - Application de la température

    // Interne (et non privée) pour être testable sans appel réseau
    func applyTemperature(_ temp: Double?) {
        currentTemperatureC = temp
        let wasHeatwave = isHeatwave

        if let t = temp, t >= heatwaveThreshold {
            isHeatwave    = true
            // +200 ml par degré au-dessus de 32°C, plafonné à +1000 ml
            adaptedGoalMl = (min((t - heatwaveThreshold) * 200, 1000) + (store?.dailyGoalMl ?? 2170)).rounded()
            if !wasHeatwave { sendHeatwaveNotification(tempC: t) }
        } else {
            isHeatwave    = false
            adaptedGoalMl = nil
        }
    }

    // MARK: - Notification canicule (une seule fois par jour)

    private func sendHeatwaveNotification(tempC: Double) {
        let today = Calendar.current.startOfDay(for: Date())
        if let last = lastNotifDate, Calendar.current.isDate(last, inSameDayAs: today) { return }
        lastNotifDate = today

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content   = UNMutableNotificationContent()
            content.title = L10n.heatwaveNotifTitle
            content.body  = String(format: L10n.heatwaveNotifBody, Int(tempC))
            content.sound = .default
            let trigger   = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request   = UNNotificationRequest(
                identifier: "aquapp_heatwave_\(today.timeIntervalSince1970)",
                content: content, trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }
}

