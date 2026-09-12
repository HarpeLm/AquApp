//
//  HydrationLiveActivityWidget.swift
//  AquApp
//
//  Created by Fabian Dargaud on 24/05/2026.
//
import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - HydrationLiveActivityWidget
// Point d'entrée du Widget Extension target.
// Ce fichier va dans le target AquAppLiveActivity (pas dans AquApp).

struct HydrationLiveActivityWidget: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(
            for: HydrationActivityAttributes.self
        ) { context in

            // ── Écran de verrouillage ─────────────────────────────────────────
            HydrationLockScreen(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in

            DynamicIsland {

                // ── Expanded — appui long ─────────────────────────────────────
                DynamicIslandExpandedRegion(.leading) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HydrationExpanded(
                        attributes: context.attributes,
                        state:      context.state
                    )
                }

            } compactLeading: {

                // ── Compact gauche — goutte + % ───────────────────────────────
                HydrationCompactLeading(state: context.state)

            } compactTrailing: {

                // ── Compact droite — mini barre ───────────────────────────────
                HydrationCompactTrailing(state: context.state)

            } minimal: {

                // ── Minimal (pill seule, concurrence avec autre app) ──────────
                Image(systemName: "drop.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        context.state.goalReached
                        ? Color(red: 0.204, green: 0.831, blue: 0.600)
                        : Color(red: 0.302, green: 0.659, blue: 0.961)
                    )
            }
            .keylineTint(Color(red: 0.302, green: 0.659, blue: 0.961))
        }
    }
}
