import Foundation
import SwiftUI
import PaceCore

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var summary: UsageSummary?
    @Published private(set) var todaySpendCents: Int?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var refreshTimer: Timer?

    init() {
        startAutoRefresh()
        Task { await refresh() }
    }

    func refresh() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            summary = try await CursorAPI.fetchUsageSummary()
            lastUpdated = Date()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        // Daily spend is supplementary; failures here must not break the main display.
        todaySpendCents = try? await CursorAPI.fetchTodaySpendCents()
    }

    /// Plain-text fallback for the menu bar while data is unavailable.
    var menuBarLabel: String {
        if errorMessage != nil, summary == nil {
            return "!"
        }
        guard let includedPercentUsed else {
            return isLoading ? "…" : "!"
        }
        return "\(Int(includedPercentUsed.rounded()))%"
    }

    var statusColor: Color {
        if hasOverspend {
            return .red
        }
        return Self.statusColor(for: includedPercentUsed)
    }

    var planDisplayName: String {
        summary?.membershipType.capitalized ?? "Unknown"
    }

    /// Guaranteed minimum included credits for auto / composer usage ($200).
    static let minimumAutoComposerIncludedCents = 20_000
    /// Guaranteed minimum included credits for named-model API usage ($400).
    static let minimumApiIncludedCents = 40_000
    /// Floor for the included pool when the API reports no usage yet.
    static let minimumIncludedCreditsCents = minimumAutoComposerIncludedCents + minimumApiIncludedCents

    /// Total included credits consumed so far (auto + API), reported directly by the API.
    /// `breakdown.total` is the *used* amount broken into included + bonus, not the pool size.
    var includedUsedCreditsCents: Int? {
        summary?.individualUsage.plan.breakdown.total
    }

    /// Included pool size. The API does not expose the pool directly, so recover it from the
    /// used amount and the reported percentage: pool = used / (percent / 100).
    var includedLimitCreditsCents: Int? {
        guard let used = includedUsedCreditsCents else { return nil }
        let percent = summary?.individualUsage.plan.totalPercentUsed ?? 0
        let derived = percent > 0 ? Int((Double(used) / (percent / 100.0)).rounded()) : 0
        return max(derived, Self.minimumIncludedCreditsCents)
    }

    /// Included pool size; alias retained for overspend accounting.
    var totalCreditsCents: Int? {
        includedLimitCreditsCents
    }

    /// Included pool usage percentage, as reported by Cursor.
    var includedPercentUsed: Double? {
        guard summary != nil, includedUsedCreditsCents != nil else { return nil }
        return summary?.individualUsage.plan.totalPercentUsed
    }

    /// Auto / composer usage as a percentage of its sub-limit, as reported by Cursor.
    var autoPercentUsed: Double? {
        guard summary != nil else { return nil }
        return summary?.individualUsage.plan.autoPercentUsed
    }

    /// Named-model API usage as a percentage of its sub-limit, as reported by Cursor.
    var apiPercentUsed: Double? {
        summary?.individualUsage.plan.apiPercentUsed
    }

    /// Named-model API included sub-limit (e.g. $400).
    var apiLimitCreditsCents: Int? {
        guard summary?.individualUsage.plan.enabled == true else { return nil }
        return summary?.individualUsage.plan.limit
    }

    /// API credits consumed, derived from the sub-limit and reported percentage so the dollar
    /// figure stays consistent with the percentage Cursor displays.
    var apiUsedCreditsCents: Int? {
        guard summary?.individualUsage.plan.enabled == true,
              let limit = apiLimitCreditsCents,
              let percent = summary?.individualUsage.plan.apiPercentUsed
        else { return nil }
        return Int((Double(limit) * percent / 100.0).rounded())
    }

    /// Auto / composer sub-limit: the included pool minus the API sub-limit.
    var autoLimitCreditsCents: Int? {
        guard let includedLimit = includedLimitCreditsCents,
              let apiLimit = apiLimitCreditsCents
        else { return nil }
        return max(includedLimit - apiLimit, Self.minimumAutoComposerIncludedCents)
    }

    /// Auto / composer credits consumed, derived from its sub-limit and reported percentage.
    var autoUsedCreditsCents: Int? {
        guard let limit = autoLimitCreditsCents,
              let percent = summary?.individualUsage.plan.autoPercentUsed
        else { return nil }
        return Int((Double(limit) * percent / 100.0).rounded())
    }

    var autoStatusColor: Color {
        Self.statusColor(for: autoPercentUsed)
    }

    var apiStatusColor: Color {
        Self.statusColor(for: apiPercentUsed)
    }

    static func statusColor(for percent: Double?) -> Color {
        guard let percent else { return .secondary }
        if percent >= 90 { return .red }
        if percent >= 70 { return .yellow }
        return .green
    }

    var includedRemainingCreditsCents: Int? {
        guard let includedLimitCreditsCents, let includedUsedCreditsCents else { return nil }
        return max(includedLimitCreditsCents - includedUsedCreditsCents, 0)
    }

    var onDemandEnabled: Bool {
        summary?.individualUsage.onDemand.enabled ?? false
    }

    var onDemandUsedCents: Int {
        summary?.individualUsage.onDemand.used ?? 0
    }

    var onDemandLimitCents: Int? {
        summary?.individualUsage.onDemand.limit
    }

    var onDemandRemainingCents: Int? {
        summary?.individualUsage.onDemand.remaining
    }

    /// Usage beyond the included credit pool.
    var includedOverageCents: Int {
        guard let used = includedUsedCreditsCents, let limit = includedLimitCreditsCents else { return 0 }
        return max(used - limit, 0)
    }

    var overspendCents: Int {
        includedOverageCents + (onDemandEnabled ? onDemandUsedCents : 0)
    }

    var hasOverspend: Bool {
        overspendCents > 0
    }

    /// Mon-Fri days between billing cycle start and end.
    var workingDaysInCycle: Int? {
        guard let start = billingCycleStartDate, let end = billingCycleEndDate, start < end else { return nil }
        let count = PaceCalculator.workingDays(from: start, to: end)
        return count > 0 ? count : nil
    }

    /// Workdays from cycle start through today (inclusive), clamped to cycle end.
    /// Uses endExclusive = startOfDay(tomorrow) ∩ cycleEnd so the current weekday counts.
    var elapsedWorkingDaysInCycle: Int? {
        guard let start = billingCycleStartDate, let end = billingCycleEndDate, start < end else { return nil }
        let calendar = Calendar.current
        let now = Date()
        guard now >= start else { return 0 }
        let endExclusive = PaceCalculator.elapsedEndExclusive(now: now, cycleEnd: end, calendar: calendar)
        return PaceCalculator.workingDays(from: start, to: endExclusive, calendar: calendar)
    }

    var paceFootnote: String? {
        guard let total = workingDaysInCycle else { return nil }
        let elapsed = elapsedWorkingDaysInCycle ?? 0
        return "Pace = pool% ÷ (\(elapsed)/\(total) workdays)"
    }

    var autoPacePercent: Double? {
        guard let pool = autoPercentUsed,
              let elapsed = elapsedWorkingDaysInCycle,
              let total = workingDaysInCycle
        else { return nil }
        return PaceCalculator.pacePercent(
            poolPercentUsed: pool,
            elapsedWorkdays: elapsed,
            totalWorkdays: total
        )
    }

    var apiPacePercent: Double? {
        guard let pool = apiPercentUsed,
              let elapsed = elapsedWorkingDaysInCycle,
              let total = workingDaysInCycle
        else { return nil }
        return PaceCalculator.pacePercent(
            poolPercentUsed: pool,
            elapsedWorkdays: elapsed,
            totalWorkdays: total
        )
    }

    /// Same thresholds as upstream pool meters; values >100 are ≥90 so they stay red.
    static func paceStatusColor(for percent: Double?) -> Color {
        Self.statusColor(for: percent)
    }

    var autoPaceStatusColor: Color {
        Self.paceStatusColor(for: autoPacePercent)
    }

    var apiPaceStatusColor: Color {
        Self.paceStatusColor(for: apiPacePercent)
    }

    /// Total quota divided by working days in the billing cycle.
    var dailyBudgetCents: Int? {
        guard let includedLimitCreditsCents, let workingDaysInCycle else { return nil }
        return includedLimitCreditsCents / workingDaysInCycle
    }

    /// Today's spend as a percentage of the daily budget. Can exceed 100%.
    var dailyUtilizationPercent: Double? {
        guard let todaySpendCents, let dailyBudgetCents, dailyBudgetCents > 0 else { return nil }
        return Double(todaySpendCents) / Double(dailyBudgetCents) * 100.0
    }

    var dailyStatusColor: Color {
        guard let dailyUtilizationPercent else { return .secondary }
        if dailyUtilizationPercent > 100 { return .red }
        if dailyUtilizationPercent >= 70 { return .yellow }
        return .green
    }

    var billingCycleEndDate: Date? {
        guard let end = summary?.billingCycleEnd else { return nil }
        return Self.iso8601Formatter.date(from: end)
    }

    var billingCycleStartDate: Date? {
        guard let start = summary?.billingCycleStart else { return nil }
        return Self.iso8601Formatter.date(from: start)
    }

    var daysUntilReset: Int? {
        guard let billingCycleEndDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: billingCycleEndDate).day ?? 0
        return max(days, 0)
    }

    var billingCycleText: String {
        guard let start = billingCycleStartDate, let end = billingCycleEndDate else {
            return "Billing cycle unavailable"
        }
        let formatter = Self.shortDateFormatter
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    var lastUpdatedText: String {
        guard let lastUpdated else { return "Never" }
        return Self.timeFormatter.string(from: lastUpdated)
    }

    static func formatDollars(cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return currencyFormatter.string(from: NSNumber(value: dollars)) ?? String(format: "$%.2f", dollars)
    }

    /// Whole-dollar amount for the compact menu bar label.
    static func formatDollarsCompact(cents: Int) -> String {
        let dollars = (Double(cents) / 100.0).rounded()
        return compactCurrencyFormatter.string(from: NSNumber(value: dollars)) ?? String(format: "$%.0f", dollars)
    }

    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    private static let compactCurrencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}
