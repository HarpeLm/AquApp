//
//  ColorHexTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 07/09/2026.
//


import XCTest
import SwiftUI
@testable import AquApp

final class ColorHexTests: XCTestCase {

    private func rgba(_ color: Color) -> (r: Double, g: Double, b: Double, a: Double) {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
        #else
        return (0, 0, 0, 1)
        #endif
    }

    func testPrimaryColors() {
        let red = rgba(Color(hex: "FF0000"))
        XCTAssertEqual(red.r, 1, accuracy: 0.01)
        XCTAssertEqual(red.g, 0, accuracy: 0.01)
        XCTAssertEqual(rgba(Color(hex: "00FF00")).g, 1, accuracy: 0.01)
        XCTAssertEqual(rgba(Color(hex: "0000FF")).b, 1, accuracy: 0.01)
    }

    func testBlackAndWhite() {
        let white = rgba(Color(hex: "FFFFFF"))
        XCTAssertEqual(white.r, 1, accuracy: 0.01)
        XCTAssertEqual(white.g, 1, accuracy: 0.01)
        XCTAssertEqual(white.b, 1, accuracy: 0.01)
        let black = rgba(Color(hex: "000000"))
        XCTAssertEqual(black.r, 0, accuracy: 0.01)
        XCTAssertEqual(black.g, 0, accuracy: 0.01)
        XCTAssertEqual(black.b, 0, accuracy: 0.01)
    }

    func testCaseInsensitive() {
        XCTAssertEqual(Color(hex: "4da8f5"), Color(hex: "4DA8F5"))
    }

    func testAppPalette_PrimaryMatchesHex() {
        XCTAssertEqual(Color.app.primary, Color(hex: "4DA8F5"))
    }

    func testKnownAppColor_MidBlue() {
        let c = rgba(Color(hex: "2B87E8"))
        XCTAssertEqual(c.r, 0x2B / 255, accuracy: 0.01)
        XCTAssertEqual(c.g, 0x87 / 255, accuracy: 0.01)
        XCTAssertEqual(c.b, 0xE8 / 255, accuracy: 0.01)
    }
}
