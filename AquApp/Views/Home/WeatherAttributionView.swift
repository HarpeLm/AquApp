import SwiftUI
import WeatherKit

// MARK: - WeatherAttributionView
// Mention « Apple Weather » + lien vers les sources légales, obligatoire
// partout où des données WeatherKit sont affichées (bannière canicule, éditeur d'objectif).

struct WeatherAttributionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var attribution: WeatherAttribution?

    var body: some View {
        Group {
            if let attribution {
                HStack(spacing: 8) {
                    AsyncImage(url: colorScheme == .dark
                               ? attribution.combinedMarkDarkURL
                               : attribution.combinedMarkLightURL) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Text(attribution.serviceName)
                            .scaledFont(size: 11, weight: .semibold)
                    }
                    .frame(height: 12)
                    .accessibilityLabel(attribution.serviceName)

                    Link(String(localized: "weather.attribution.sources"),
                         destination: attribution.legalPageURL)
                        .scaledFont(size: 11)
                }
                .foregroundStyle(.secondary)
            }
        }
        // Sans capacité WeatherKit (ou hors ligne), rien ne s'affiche
        .task { attribution = try? await WeatherService.shared.attribution }
    }
}

#Preview {
    WeatherAttributionView()
        .padding()
}
