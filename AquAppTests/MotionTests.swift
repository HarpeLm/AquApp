import XCTest
import SwiftUI
@testable import AquApp

/// « Réduire les animations » : rebonds et glissements deviennent des fondus courts.
final class MotionTests: XCTestCase {

    override func tearDown() {
        Motion.reduceOverride = nil
        super.tearDown()
    }

    func testAnimations_areKept_whenMotionIsNotReduced() {
        Motion.reduceOverride = false
        let spring = Animation.spring(response: 0.4, dampingFraction: 0.75)
        XCTAssertEqual(Motion.animation(spring), spring)
    }

    func testAnimations_becomeAShortFade_whenMotionIsReduced() {
        Motion.reduceOverride = true
        let spring = Animation.spring(response: 0.4, dampingFraction: 0.75)
        XCTAssertEqual(Motion.animation(spring), .easeInOut(duration: 0.2))
        XCTAssertEqual(Motion.animation(.spring()), .easeInOut(duration: 0.2))
    }

    func testOverride_winsOverTheSystemSetting() {
        Motion.reduceOverride = true
        XCTAssertTrue(Motion.isReduced)
        Motion.reduceOverride = false
        XCTAssertFalse(Motion.isReduced)
        Motion.reduceOverride = nil
        XCTAssertEqual(Motion.isReduced, UIAccessibility.isReduceMotionEnabled)
    }
}
