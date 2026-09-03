import Foundation
import SwiftUI

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
        todaySpendCents = try? await CursorAPI.fetchTodaySpendCents(cycleStart: billingCycleStartDate)
        if let cycleStart = billingCycleStartDate,
           Calendar.current.isDate(Date(), inSameDayAs: cycleStart),
           let includedUsed = includedUsedCreditsCents
        {
            todaySpendCents = includedUsed
        }
    }

    /// Plain-text fallback for the menu bar while data is unavailable.
    var menuBarLabel: String {
        if errorMessage != nil, summary == nil {
            return "!"
        }
        guard let includedPercentUsed = quotaPercentUsed else {
            return isLoading ? "…" : "!"
        }
        return "\(Int(includedPercentUsed.rounded()))%"
    }

    /// Included-usage color from percent thresholds only. Overspend is a separate red badge.
    var statusColor: Color {
        Self.statusColor(for: quotaPercentUsed)
    }

    var planDisplayName: String {
        summary?.resolvedMembershipType.capitalized ?? "Unknown"
    }

    /// Total included credits consumed so far. `breakdown.total` is used amount, not pool size.
    var includedUsedCreditsCents: Int? {
        summary?.includedUsedCents
    }

    /// Included pool size: `overall.limit` when present, otherwise used / (percent / 100).
    /// Individual plans floor to $600; Enterprise / team never use that floor.
    var includedLimitCreditsCents: Int? {
        summary?.includedLimitCents
    }

    /// Included pool size; alias retained for overspend accounting.
    var totalCreditsCents: Int? {
        includedLimitCreditsCents
    }

    /// Included pool usage percentage, as reported by Cursor.
    var includedPercentUsed: Double? {
        summary?.includedPercentUsed
    }

    /// Menu-bar quota: blended included % when present, otherwise the first pool %.
    var quotaPercentUsed: Double? {
        includedPercentUsed ?? cursorModelsPercentUsed ?? otherModelsPercentUsed
    }

    /// Cursor Models pool (Auto, Composer, Cursor Grok). Percent only — the API has no dollar cap for this pool.
    var cursorModelsPercentUsed: Double? {
        summary?.cursorModelsPercentUsed
    }

    /// Other Models pool (named / third-party).
    var otherModelsPercentUsed: Double? {
        summary?.otherModelsPercentUsed
    }

    var otherModelsLimitCreditsCents: Int? {
        summary?.otherModelsLimitCents
    }

    var otherModelsUsedCreditsCents: Int? {
        summary?.otherModelsUsedCents
    }

    var cursorModelsStatusColor: Color {
        Self.statusColor(for: cursorModelsPercentUsed)
    }

    var otherModelsStatusColor: Color {
        Self.statusColor(for: otherModelsPercentUsed)
    }

    var includedStatusColor: Color {
        Self.statusColor(for: includedPercentUsed)
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
        summary?.resolvedOnDemand?.isEnabled ?? false
    }

    var onDemandUsedCents: Int {
        summary?.resolvedOnDemand?.usedCents ?? 0
    }

    var onDemandLimitCents: Int? {
        summary?.resolvedOnDemand?.limit
    }

    var onDemandRemainingCents: Int? {
        summary?.resolvedOnDemand?.remaining
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
        let calendar = Calendar.current
        var count = 0
        var day = calendar.startOfDay(for: start)
        let lastDay = calendar.startOfDay(for: end)
        while day < lastDay {
            if !calendar.isDateInWeekend(day) {
                count += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return count > 0 ? count : nil
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
