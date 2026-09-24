//
//  SectionHeader.swift
//  AquApp
//
//  Created by Fabian Dargaud on 15/03/2026.
//
import SwiftUI

struct SectionHeader: View {
    let title: String
    let sfSymbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: sfSymbol)
                .scaledFont(size: 13, weight: .semibold)
                .foregroundColor(color)
                .accessibilityHidden(true)
            Text(title)
                .scaledFont(size: 13, weight: .semibold)
                .foregroundColor(.secondary)
        }
        .padding(.leading, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    SectionHeader(title: "Hydratation", sfSymbol: "drop.fill", color: Color.app.primary)
        .padding()
}
