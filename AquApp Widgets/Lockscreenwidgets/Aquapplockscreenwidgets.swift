//
//  Aquapplockscreenwidgets.swift
//  AquApp
//
//  Created by Fabian Dargaud on 03/07/2026.
//

//
//  AquAppLockScreenWidgets.swift
//  AquAppWidgetExtension
//
//  Widgets Lock Screen (iOS 16+) — familles accessoryCircular,
//  accessoryRectangular, accessoryInline.
//
//  Réutilisent AquWidgetData et AquProvider déjà définis dans AquAppWidget.swift.
//  Ce fichier doit être ajouté à la MÊME target (AquApp WidgetsExtension).
//
//  IMPORTANT : les widgets Lock Screen sont rendus en monochrome par iOS —
//  toute couleur définie ici est ignorée sur l'écran verrouillé (iOS applique
//  automatiquement blanc/tinté). Le code utilise donc .white partout, qui est
//  la seule valeur cohérente avec le rendu système.

import WidgetKit
import SwiftUI

// MARK: - Cercle (accessoryCircular)

struct AquLockCircularView: View {
    let data: AquWidgetData

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: 3.5)

            Circle()
                .trim(from: 0, to: min(data.progress, 1))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Le texte reste dans le rayon intérieur, largement dégagé de l'anneau
            Text("\(Int(data.progress * 100))%")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
        }
    }
}

struct AquLockCircularWidget: Widget {
    let kind = "AquLockCircularWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AquProvider()) { entry in
            AquLockCircularView(data: entry.data)
        }
        .configurationDisplayName("Progression (cercle)")
        .description("Pourcentage de l'objectif du jour, en anneau.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Rectangle (accessoryRectangular)

struct AquLockRectangularView: View {
    let data: AquWidgetData

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 10))
                Text("\(Int(data.todayMl)) / \(Int(data.goalMl)) ml")
                    .font(.system(size: 13, weight: .bold))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }

            // Barre de progression fine
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.25))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white)
                        .frame(width: geo.size.width * min(data.progress, 1))
                }
            }
            .frame(height: 5)

            Text("\(Int(data.progress * 100))% de l'objectif")
                .font(.system(size: 10))
                .opacity(0.75)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
    }
}

struct AquLockRectangularWidget: Widget {
    let kind = "AquLockRectangularWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AquProvider()) { entry in
            AquLockRectangularView(data: entry.data)
        }
        .configurationDisplayName("Progression (rectangle)")
        .description("Volume bu, objectif et pourcentage du jour.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - Inline (accessoryInline)

struct AquLockInlineView: View {
    let data: AquWidgetData

    var body: some View {
        // accessoryInline ne supporte qu'une seule ligne texte + une seule icône.
        // ViewThatFits garantit qu'iOS choisit le rendu qui tient dans l'espace
        // disponible sans troncature disgracieuse.
        Label {
            Text("\(Int(data.todayMl)) / \(Int(data.goalMl)) ml")
        } icon: {
            Image(systemName: "drop.fill")
        }
    }
}

struct AquLockInlineWidget: Widget {
    let kind = "AquLockInlineWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AquProvider()) { entry in
            AquLockInlineView(data: entry.data)
        }
        .configurationDisplayName("Progression (ligne)")
        .description("Volume bu et objectif, sur la ligne de la date.")
        .supportedFamilies([.accessoryInline])
    }
}
