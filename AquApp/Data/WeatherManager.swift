import Foundation
import CoreLocation
import UserNotifications
import SwiftUI
import Combine

// MARK: - WeatherManager
// 1. Géolocalisation (CoreLocation)
// 2. Température via Open-Meteo (gratuit, sans clé API)
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

    // MARK: - Fetch température avec timeout

    private func fetchTemperature(lat: Double, lon: Double) {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            URLQueryItem(name: "latitude",      value: String(format: "%.4f", lat)),
            URLQueryItem(name: "longitude",     value: String(format: "%.4f", lon)),
            URLQueryItem(name: "current",       value: "temperature_2m"),
            URLQueryItem(name: "forecast_days", value: "1"),
        ]
        guard let url = comps.url else { return }

        // ✅ Timeout réseau : 5 secondes max pour ne pas bloquer l'UI
        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        Task { @MainActor in
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                // Vérifie que le serveur a répondu avec un code HTTP 200
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    applyTemperature(nil)
                    return
                }

                let json = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                applyTemperature(json.current.temperature_2m)

            } catch URLError.timedOut {
                // Timeout silencieux — on désactive la bannière sans crasher
                applyTemperature(nil)
            } catch {
                applyTemperature(nil)
            }
        }
    }

    // MARK: - Application de la température

    private func applyTemperature(_ temp: Double?) {
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

// MARK: - Décodage Open-Meteo

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable { let temperature_2m: Double }
    let current: Current
}
