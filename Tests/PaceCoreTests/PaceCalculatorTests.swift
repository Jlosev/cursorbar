import XCTest
@testable import PaceCore

final class PaceCalculatorTests: XCTestCase {
    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        utc.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testWorkingDays_excludesWeekends_halfOpen() {
        // Mon 2026-08-03 .. Fri 2026-08-14 exclusive end Sat 2026-08-15
        // Weekdays: 3–7, 10–14 = 10 days
        let start = date(2026, 8, 3)
        let end = date(2026, 8, 15)
        XCTAssertEqual(PaceCalculator.workingDays(from: start, to: end, calendar: utc), 10)
    }

    func testWorkingDays_emptyWhenStartNotBeforeEnd() {
        let day = date(2026, 8, 3)
        XCTAssertEqual(PaceCalculator.workingDays(from: day, to: day, calendar: utc), 0)
    }

    func testPace_onPlan_midCycle() {
        // 50% used, 50% of workdays elapsed → pace 100
        let pace = PaceCalculator.pacePercent(
            poolPercentUsed: 50,
            elapsedWorkdays: 5,
            totalWorkdays: 10
        )
        XCTAssertEqual(pace!, 100, accuracy: 0.001)
    }

    func testPace_aheadOfPlan() {
        // 40% used, 20% time elapsed → pace 200
        let pace = PaceCalculator.pacePercent(
            poolPercentUsed: 40,
            elapsedWorkdays: 2,
            totalWorkdays: 10
        )
        XCTAssertEqual(pace!, 200, accuracy: 0.001)
    }

    func testPace_usesMinOneElapsed_toAvoidDivZero() {
        let pace = PaceCalculator.pacePercent(
            poolPercentUsed: 5,
            elapsedWorkdays: 0,
            totalWorkdays: 20
        )
        // 5 / (1/20) = 100
        XCTAssertEqual(pace!, 100, accuracy: 0.001)
    }

    func testPace_nilWhenTotalWorkdaysZero() {
        XCTAssertNil(
            PaceCalculator.pacePercent(
                poolPercentUsed: 10,
                elapsedWorkdays: 1,
                totalWorkdays: 0
            )
        )
    }

    func testElapsedEndExclusive_includesToday() {
        let now = date(2026, 8, 5) // Wednesday
        let cycleEnd = date(2026, 8, 31)
        let endEx = PaceCalculator.elapsedEndExclusive(now: now, cycleEnd: cycleEnd, calendar: utc)
        XCTAssertEqual(endEx, date(2026, 8, 6))
        // Mon–Wed inclusive → 3
        XCTAssertEqual(
            PaceCalculator.workingDays(from: date(2026, 8, 3), to: endEx, calendar: utc),
            3
        )
    }

    func testElapsedEndExclusive_clampsToCycleEnd() {
        let now = date(2026, 8, 20)
        let cycleEnd = date(2026, 8, 15)
        let endEx = PaceCalculator.elapsedEndExclusive(now: now, cycleEnd: cycleEnd, calendar: utc)
        XCTAssertEqual(endEx, date(2026, 8, 15))
    }

    func testWorkingDays_weekendOnlyWindow_isZero() {
        // Sat→Sun half-open ending Monday → Sat+Sun = 0 weekdays
        XCTAssertEqual(
            PaceCalculator.workingDays(from: date(2026, 8, 8), to: date(2026, 8, 10), calendar: utc),
            0
        )
    }
}
