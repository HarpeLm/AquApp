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
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.leading, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    SectionHeader(title: "Hydratation", sfSymbol: "drop.fill", color: Color(hex: "4DA8F5"))
        .padding()
}
