import XCTest
@testable import PaceCore

final class MenuBarChromeTests: XCTestCase {
    func testPrefersChromeWhenChromeIsDarkAndAppIsLight() {
        XCTAssertTrue(
            MenuBarChrome.prefersLightGaugeText(chromeIsDark: true, appIsDark: false)
        )
    }

    func testPrefersChromeWhenChromeIsLightAndAppIsDark() {
        XCTAssertFalse(
            MenuBarChrome.prefersLightGaugeText(chromeIsDark: false, appIsDark: true)
        )
    }

    func testFallsBackToAppWhenChromeUnknown() {
        XCTAssertFalse(
            MenuBarChrome.prefersLightGaugeText(chromeIsDark: nil, appIsDark: false)
        )
        XCTAssertTrue(
            MenuBarChrome.prefersLightGaugeText(chromeIsDark: nil, appIsDark: true)
        )
    }

    func testDetectsStatusBarWindowClassNames() {
        XCTAssertTrue(MenuBarChrome.looksLikeStatusBarWindow(className: "NSStatusBarWindow"))
        XCTAssertTrue(MenuBarChrome.looksLikeStatusBarWindow(className: "_NSStatusBarWindow"))
        XCTAssertTrue(MenuBarChrome.looksLikeStatusBarWindow(className: "NSStatusBar"))
        XCTAssertTrue(MenuBarChrome.looksLikeStatusBarWindow(className: "NSStatusItem"))
        XCTAssertFalse(MenuBarChrome.looksLikeStatusBarWindow(className: "NSWindow"))
        XCTAssertFalse(MenuBarChrome.looksLikeStatusBarWindow(className: "NSPanel"))
        XCTAssertFalse(MenuBarChrome.looksLikeStatusBarWindow(className: "NSMenuBar"))
        XCTAssertFalse(MenuBarChrome.looksLikeStatusBarWindow(className: ""))
    }

    func testIsDarkAppearanceName_darkVariants() {
        XCTAssertTrue(MenuBarChrome.isDark(appearanceName: "NSAppearanceNameDarkAqua"))
        XCTAssertTrue(MenuBarChrome.isDark(appearanceName: "NSAppearanceNameVibrantDark"))
        XCTAssertTrue(MenuBarChrome.isDark(appearanceName: "NSAppearanceNameAccessibilityHighContrastDarkAqua"))
        XCTAssertFalse(MenuBarChrome.isDark(appearanceName: "NSAppearanceNameAqua"))
        XCTAssertFalse(MenuBarChrome.isDark(appearanceName: "NSAppearanceNameVibrantLight"))
        XCTAssertFalse(MenuBarChrome.isDark(appearanceName: ""))
    }
}
