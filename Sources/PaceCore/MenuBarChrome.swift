public enum MenuBarChrome {
    /// Light gauge text (white + dark halo) when the hosting strip is dark.
    /// Chrome wins over the app/system appearance; `nil` chrome falls back to the app.
    public static func prefersLightGaugeText(chromeIsDark: Bool?, appIsDark: Bool) -> Bool {
        chromeIsDark ?? appIsDark
    }

    /// MenuBarExtra / NSStatusItem live in a status-bar window, not a normal NSWindow.
    /// Do not match `NSMenuBar` (the File/Edit menu). That is a different strip.
    public static func looksLikeStatusBarWindow(className: String) -> Bool {
        let name = className.lowercased()
        return name.contains("statusbar") || name.contains("statusitem")
    }

    /// AppKit `bestMatch` names: any Dark* appearance means light gauge text.
    public static func isDark(appearanceName: String) -> Bool {
        appearanceName.localizedCaseInsensitiveContains("Dark")
    }
}
