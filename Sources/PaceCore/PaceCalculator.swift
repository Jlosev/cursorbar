import Foundation

public enum PaceCalculator {
    /// End bound so “today” counts as an elapsed workday when used with `workingDays`.
    public static func elapsedEndExclusive(
        now: Date,
        cycleEnd: Date,
        calendar: Calendar = .current
    ) -> Date {
        let todayStart = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        let cycleEndStart = calendar.startOfDay(for: cycleEnd)
        return min(tomorrow, cycleEndStart)
    }

    /// Count Mon–Fri days in half-open interval `[start, endExclusive)`.
    public static func workingDays(
        from start: Date,
        to endExclusive: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard start < endExclusive else { return 0 }
        var count = 0
        var day = calendar.startOfDay(for: start)
        let lastDay = calendar.startOfDay(for: endExclusive)
        while day < lastDay {
            if !calendar.isDateInWeekend(day) {
                count += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return count
    }

    /// Pace index: `100` = usage matches elapsed fraction of cycle workdays.
    /// Uses `max(elapsedWorkdays, 1)` so early-cycle / weekend start does not divide by zero.
    public static func pacePercent(
        poolPercentUsed: Double,
        elapsedWorkdays: Int,
        totalWorkdays: Int
    ) -> Double? {
        guard totalWorkdays > 0 else { return nil }
        let elapsed = max(elapsedWorkdays, 1)
        let fraction = Double(elapsed) / Double(totalWorkdays)
        return poolPercentUsed / fraction
    }
}
