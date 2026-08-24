import AppKit
import Combine
import PaceCore

@MainActor
final class MenuBarChromeMonitor: ObservableObject {
    @Published private(set) var isDark: Bool

    private let app: NSApplication
    private var appearanceObservation: NSKeyValueObservation?

    init(app: NSApplication = .shared) {
        self.app = app
        self.isDark = Self.resolve(app: app)
        start()
    }

    // Process-lifetime object. Do not add @MainActor deinit observer cleanup
    // (Swift 6 isolation). Tokens stay until the accessory app exits.

    func refresh() {
        let next = Self.resolve(app: app)
        if next != isDark {
            isDark = next
        }
        observeChromeWindow()
    }

    static func isDark(_ appearance: NSAppearance) -> Bool {
        let matched = appearance.bestMatch(from: [.darkAqua, .aqua]) ?? appearance.name
        return MenuBarChrome.isDark(appearanceName: matched.rawValue)
    }

    static func chromeWindow(in windows: [NSWindow]) -> NSWindow? {
        windows.first { window in
            MenuBarChrome.looksLikeStatusBarWindow(className: window.className)
                || window.level == .statusBar
        }
    }

    static func resolve(app: NSApplication) -> Bool {
        let chrome = chromeWindow(in: app.windows)
        let chromeIsDark = chrome.map { isDark($0.effectiveAppearance) }
        let appIsDark = isDark(app.effectiveAppearance)
        return MenuBarChrome.prefersLightGaugeText(chromeIsDark: chromeIsDark, appIsDark: appIsDark)
    }

    private func start() {
        _ = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        _ = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        observeChromeWindow()
    }

    private func observeChromeWindow() {
        let chrome = Self.chromeWindow(in: app.windows)
        appearanceObservation = chrome?.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.refresh() }
        }
    }
}
