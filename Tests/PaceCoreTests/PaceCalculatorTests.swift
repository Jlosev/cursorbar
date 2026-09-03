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
        let start = date(2026, 8, 3)
        let end = date(2026, 8, 15)
        XCTAssertEqual(PaceCalculator.workingDays(from: start, to: end, calendar: utc), 10)
    }

    func testRemainingWorkdays_excludesToday_startsTomorrow() {
        // Wed 2026-08-05 → cycle end Mon 2026-08-17 (exclusive end start-of-day Aug 17)
        // remaining from tomorrow: Thu 6, Fri 7, Mon 10, Tue 11, Wed 12, Thu 13, Fri 14 = 7
        let now = date(2026, 8, 5)
        let cycleEnd = date(2026, 8, 17)
        XCTAssertEqual(
            PaceCalculator.remainingWorkdays(now: now, cycleEnd: cycleEnd, calendar: utc),
            7
        )
    }

    func testRemainingWorkdays_zeroWhenPastEnd() {
        let now = date(2026, 8, 20)
        let cycleEnd = date(2026, 8, 15)
        XCTAssertEqual(
            PaceCalculator.remainingWorkdays(now: now, cycleEnd: cycleEnd, calendar: utc),
            0
        )
    }

    func testRemainingWorkdays_zeroOnLastWorkday() {
        // Friday 2026-08-14, cycle ends Mon 2026-08-17 → no future workdays before end
        let now = date(2026, 8, 14)
        let cycleEnd = date(2026, 8, 17)
        XCTAssertEqual(
            PaceCalculator.remainingWorkdays(now: now, cycleEnd: cycleEnd, calendar: utc),
            0
        )
    }

    func testOnPace_disjointWindows_eveningUtilizationIs100() {
        // $400 pool, even $20/day over 20 workdays. After 10 elapsed days, used = $200.
        // Elapsed includes today; remaining starts tomorrow → 10 future days, not 11.
        let used = 20_000
        let remaining = 20_000
        let elapsed = 10
        let remainingDays = 10
        let avg = PaceCalculator.avgDailyCents(usedCents: used, elapsedWorkdays: elapsed)!
        let budget = PaceCalculator.dailyBudgetCents(
            remainingCents: remaining,
            remainingWorkdays: remainingDays
        )!
        let pct = PaceCalculator.dailyUtilizationPercent(
            avgDailyCents: avg,
            dailyBudgetCents: budget
        )!
        XCTAssertEqual(avg, 2_000)
        XCTAssertEqual(budget, 2_000)
        XCTAssertEqual(pct, 100.0, accuracy: 0.01)
    }

    func testDailyBudget_redistributesRemaining() {
        // $278 remaining, 10 workdays left → $27.80/day
        let budget = PaceCalculator.dailyBudgetCents(remainingCents: 27_800, remainingWorkdays: 10)
        XCTAssertEqual(budget, 2_780)
    }

    func testDailyBudget_quietDaysRaiseAllowance() {
        // Same $278 remaining but only 5 days left → $55.60/day
        let budget = PaceCalculator.dailyBudgetCents(remainingCents: 27_800, remainingWorkdays: 5)
        XCTAssertEqual(budget, 5_560)
    }

    func testDailyBudget_usesMinOneDay() {
        let budget = PaceCalculator.dailyBudgetCents(remainingCents: 1_000, remainingWorkdays: 0)
        XCTAssertEqual(budget, 1_000)
    }

    func testDailyBudget_nilWhenRemainingNegative() {
        XCTAssertNil(PaceCalculator.dailyBudgetCents(remainingCents: -1, remainingWorkdays: 5))
    }

    func testDailyBudget_zeroRemainingYieldsZero() {
        XCTAssertEqual(PaceCalculator.dailyBudgetCents(remainingCents: 0, remainingWorkdays: 5), 0)
    }

    func testAvgDaily_dividesUsedByElapsed() {
        // $122 used over 5 elapsed days → $24.40/day
        let avg = PaceCalculator.avgDailyCents(usedCents: 12_200, elapsedWorkdays: 5)
        XCTAssertEqual(avg, 2_440)
    }

    func testAvgDaily_usesMinOneElapsed() {
        let avg = PaceCalculator.avgDailyCents(usedCents: 500, elapsedWorkdays: 0)
        XCTAssertEqual(avg, 500)
    }


    func testD1_apiRemaining278of400_notCyclePacePanic() {
        // Motivating dogfood: $122 used of $400 → 30.5% pool; if only ~27% of cycle
        // elapsed, old cycle-pace ≈ 114% red. New metric with 10 workdays left:
        // budget = 27800/10 = 2780; avg = 12200/5 = 2440 → ~87.8% (not 114).
        let budget = PaceCalculator.dailyBudgetCents(remainingCents: 27_800, remainingWorkdays: 10)!
        let avg = PaceCalculator.avgDailyCents(usedCents: 12_200, elapsedWorkdays: 5)!
        let pct = PaceCalculator.dailyUtilizationPercent(avgDailyCents: avg, dailyBudgetCents: budget)!
        XCTAssertEqual(budget, 2_780)
        XCTAssertEqual(avg, 2_440)
        XCTAssertEqual(pct, 2440.0 / 2780.0 * 100.0, accuracy: 0.01)
        XCTAssertLessThan(pct, 100) // must not be the false 114% panic
    }

    func testDailyUtilization_onBudget() {
        // avg 2440 / budget 2780 ≈ 87.77%
        let pct = PaceCalculator.dailyUtilizationPercent(avgDailyCents: 2_440, dailyBudgetCents: 2_780)
        XCTAssertEqual(pct!, 2440.0 / 2780.0 * 100.0, accuracy: 0.01)
    }

    func testDailyUtilization_overBudget() {
        let pct = PaceCalculator.dailyUtilizationPercent(avgDailyCents: 4_000, dailyBudgetCents: 2_000)
        XCTAssertEqual(pct!, 200.0, accuracy: 0.01)
    }

    func testDailyUtilization_nilWhenBudgetZero() {
        XCTAssertNil(PaceCalculator.dailyUtilizationPercent(avgDailyCents: 100, dailyBudgetCents: 0))
    }

    func testDailyUtilization_zeroTodayIsZeroPercent() {
        let pct = PaceCalculator.dailyUtilizationPercent(avgDailyCents: 0, dailyBudgetCents: 2_000)
        XCTAssertEqual(pct!, 0.0, accuracy: 0.01)
    }

    func testDailyUtilization_nilSpendIsZeroPercentWhenBudgetExists() {
        let pct = PaceCalculator.dailyUtilizationPercent(spendCents: nil, dailyBudgetCents: 2_000)
        XCTAssertEqual(pct!, 0.0, accuracy: 0.01)
    }

    func testDailyUtilization_nilBudgetStaysNilEvenWhenSpendIsZero() {
        XCTAssertNil(PaceCalculator.dailyUtilizationPercent(spendCents: 0, dailyBudgetCents: nil))
    }

    func testMenuBarBarFill_zeroPercentKeepsFullTrackWidth() {
        XCTAssertEqual(MenuBarBarFill.width(percent: 0, in: 38), 0)
        XCTAssertEqual(MenuBarBarFill.width(percent: nil, in: 38), 0)
        XCTAssertEqual(MenuBarBarFill.width(percent: 50, in: 38), 19, accuracy: 0.01)
        XCTAssertEqual(MenuBarBarFill.width(percent: 200, in: 38), 38, accuracy: 0.01)
    }

    func testPoolClassifier_firstPartyIsAuto() {
        XCTAssertEqual(UsagePoolClassifier.pool(forModel: "composer-2.5-fast"), .auto)
        XCTAssertEqual(UsagePoolClassifier.pool(forModel: "cursor-grok-4.6-high-fast"), .auto)
        XCTAssertEqual(UsagePoolClassifier.pool(forModel: "default"), .auto)
        XCTAssertEqual(UsagePoolClassifier.pool(forModel: "auto"), .auto)
    }

    func testPoolClassifier_namedModelsAreAPI() {
        XCTAssertEqual(UsagePoolClassifier.pool(forModel: "claude-opus-5-thinking-high"), .api)
        XCTAssertEqual(UsagePoolClassifier.pool(forModel: "gpt-5"), .api)
        XCTAssertEqual(UsagePoolClassifier.pool(forModel: nil), .api)
        XCTAssertEqual(UsagePoolClassifier.pool(forModel: ""), .api)
    }

    // Keep existing elapsedEndExclusive tests
    func testElapsedEndExclusive_includesToday() {
        let now = date(2026, 8, 5)
        let cycleEnd = date(2026, 8, 31)
        let endEx = PaceCalculator.elapsedEndExclusive(now: now, cycleEnd: cycleEnd, calendar: utc)
        XCTAssertEqual(endEx, date(2026, 8, 6))
    }

    func testElapsedEndExclusive_clampsToCycleEnd() {
        let now = date(2026, 8, 20)
        let cycleEnd = date(2026, 8, 15)
        XCTAssertEqual(
            PaceCalculator.elapsedEndExclusive(now: now, cycleEnd: cycleEnd, calendar: utc),
            date(2026, 8, 15)
        )
    }

    func testTodaySpendWindow_usesMidnightWhenCycleStartedEarlier() {
        let now = utc.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 15))!
        let cycleStart = utc.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 13, minute: 22, second: 40))!
        XCTAssertEqual(
            PaceCalculator.todaySpendWindowStart(now: now, cycleStart: cycleStart, calendar: utc),
            date(2026, 9, 10)
        )
    }

    func testTodaySpendWindow_clipsToCycleStartOnResetDay() {
        // Cycle reset mid-afternoon; morning events billed on the previous subscription.
        let now = utc.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 16, minute: 42))!
        let cycleStart = utc.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 13, minute: 22, second: 40))!
        XCTAssertEqual(
            PaceCalculator.todaySpendWindowStart(now: now, cycleStart: cycleStart, calendar: utc),
            cycleStart
        )
    }

    func testTodaySpendWindow_midnightWhenCycleStartMissing() {
        let now = utc.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 16))!
        XCTAssertEqual(
            PaceCalculator.todaySpendWindowStart(now: now, cycleStart: nil, calendar: utc),
            date(2026, 9, 3)
        )
    }

    func testIsCycleStartDay_trueOnResetCalendarDay() {
        let now = utc.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 18))!
        let cycleStart = utc.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 13, minute: 22))!
        XCTAssertTrue(PaceCalculator.isCycleStartDay(now: now, cycleStart: cycleStart, calendar: utc))
    }

    func testIsCycleStartDay_falseOnLaterDay() {
        let now = utc.date(from: DateComponents(year: 2026, month: 9, day: 4, hour: 10))!
        let cycleStart = utc.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 13, minute: 22))!
        XCTAssertFalse(PaceCalculator.isCycleStartDay(now: now, cycleStart: cycleStart, calendar: utc))
    }

    func testScalePoolCents_dayOneMatchesIncludedTotal() {
        // Events 1435 + 530 = 1965.14 rounded separately can drift; snap to included 1965.
        let scaled = PaceCalculator.scalePoolCents(autoCents: 1_435, apiCents: 531, toTotal: 1_965)
        XCTAssertEqual(scaled.auto + scaled.api, 1_965)
        XCTAssertEqual(scaled.auto, 1_434)
        XCTAssertEqual(scaled.api, 531)
    }

    func testScalePoolCents_identityWhenAlreadyEqual() {
        let scaled = PaceCalculator.scalePoolCents(autoCents: 1_446, apiCents: 848, toTotal: 2_294)
        XCTAssertEqual(scaled.auto, 1_446)
        XCTAssertEqual(scaled.api, 848)
    }

    func testCursorUsed_isIncludedMinusOther() {
        XCTAssertEqual(PaceCalculator.cursorModelsUsedCents(includedUsed: 2_294, otherUsed: 848), 1_446)
        XCTAssertEqual(PaceCalculator.cursorModelsUsedCents(includedUsed: 100, otherUsed: 150), 0)
    }
}
