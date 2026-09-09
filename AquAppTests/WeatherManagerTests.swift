//
//  WeatherManagerTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 07/09/2026.
//


import XCTest
@testable import AquApp

final class WeatherManagerContractTests: XCTestCase {

    /// Contrat : +200 ml/degré au-dessus de 32 °C, plafond +1000 ml, base 2170 ml.
    func testHeatwaveFormula_ContractTable() {
        let base = 2170.0
        let table: [(Double, Bool, Double)] = [
            (-10, false, 0), (0, false, 0), (31.99, false, 0),
            (32.0, true, 0), (32.5, true, 100), (33, true, 200),
            (35, true, 600), (36.9, true, 980),
            (37, true, 1000), (37.5, true, 1000), (45, true, 1000),
        ]
        for (temp, isHeat, bonus) in table {
            XCTAssertEqual(temp >= 32.0, isHeat, "temp=\(temp)")
            let extra = isHeat ? min((temp - 32.0) * 200, 1000) : 0
            XCTAssertEqual((extra + base).rounded(), bonus + base, accuracy: 0.5, "temp=\(temp)")
        }
    }
}
