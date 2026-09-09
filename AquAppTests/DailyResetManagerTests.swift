//
//  DailyResetManagerTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 07/09/2026.
//

import XCTest
@testable import AquApp

final class WeekdayMathTests: XCTestCase {

    func testDaysUntilMonday_AllWeekdays() {
        let table: [(Int, Int)] = [(1, 1), (2, 7), (3, 6), (4, 5), (5, 4), (6, 3), (7, 2)]
        for (weekday, expected) in table {
            let days = (weekday == 2) ? 7 : (9 - weekday) % 7
            XCTAssertEqual(days, expected, "weekday=\(weekday)")
        }
    }

    func testKnownDates_September2026() {
        let cal = Calendar.current
        let table: [(Int, Int)] = [(6, 1), (7, 7), (8, 6), (9, 5), (10, 4), (11, 3), (12, 2)]
        for (day, expected) in table {
            let date = cal.date(from: DateComponents(year: 2026, month: 9, day: day))!
            let weekday = cal.component(.weekday, from: date)
            let days = (weekday == 2) ? 7 : (9 - weekday) % 7
            XCTAssertEqual(days, expected, "day=\(day)")
        }
    }
}
