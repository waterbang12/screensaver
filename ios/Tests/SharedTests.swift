import XCTest
import SwiftUI

final class SharedTests: XCTestCase {
    func testDefaultsDecodeFromSharedJSON() {
        let settings = LauncherSettings.defaults
        XCTAssertEqual(settings.themeId, "void")
        XCTAssertFalse(settings.visibleShortcuts.isEmpty)
    }

    func testThemesLoadFromSharedJSON() {
        let ids = ThemeLibrary.all.map(\.id)
        XCTAssertEqual(ids, ["void", "mono", "terminal", "washi"])
    }

    func testPresetsLoad() {
        XCTAssertNotNil(PresetLibrary.named("music"))
    }

    func testPartialJSONKeepsDefaults() throws {
        let settings = try LauncherSettings.decodeMerged(Data(#"{"themeId":"washi","layout":{"alignment":"center"}}"#.utf8))
        XCTAssertEqual(settings.themeId, "washi")
        XCTAssertEqual(settings.layout.alignment, .center)
        XCTAssertEqual(settings.layout.itemSpacing, LauncherSettings.defaults.layout.itemSpacing)
        XCTAssertEqual(settings.shortcuts, LauncherSettings.defaults.shortcuts)
    }

    func testRoundTrip() throws {
        var settings = LauncherSettings.defaults
        settings.typography.clockSize = 99
        settings.header.motto = "quiet"
        let decoded = try LauncherSettings.decodeMerged(settings.encoded())
        XCTAssertEqual(decoded, settings)
    }

    func testInvalidJSONThrows() {
        XCTAssertThrowsError(try LauncherSettings.decodeMerged(Data("not json".utf8)))
        XCTAssertThrowsError(try LauncherSettings.decodeMerged(Data(#"{"appearance":"sepia"}"#.utf8)))
    }

    func testViaAppRoundTrip() {
        XCTAssertNil(Shortcut(id: "x", name: "Empty", url: "  ", visible: true).targetURL)
        XCTAssertNil(Shortcut(id: "x", name: "No scheme", url: "music", visible: true).targetURL)

        let valid = Shortcut(id: "y", name: "Work", url: "shortcuts://run-shortcut?name=Work%20Mode", visible: true)
        XCTAssertEqual(valid.launchURL(mode: .direct), valid.targetURL)
        guard let routed = valid.launchURL(mode: .viaApp) else {
            return XCTFail("via-app URL should be built")
        }
        XCTAssertEqual(routed.scheme, "margin")
        XCTAssertEqual(Shortcut.target(fromRoutedURL: routed), valid.targetURL)
    }

    func testManualShortcutParser() {
        let parsed = ManualShortcutParser.parse("Music; Notes=mobilenotes://\nWork=shortcuts://run-shortcut?name=Work;  ")
        XCTAssertEqual(parsed.map(\.name), ["Music", "Notes", "Work"])
        XCTAssertEqual(parsed[0].url, "music://")
        XCTAssertEqual(parsed[2].url, "shortcuts://run-shortcut?name=Work")
    }

    func testHexParsing() {
        XCTAssertNotNil(Color(hex: "#D71921"))
        XCTAssertNotNil(Color(hex: "D71921FF"))
        XCTAssertNil(Color(hex: ""))
        XCTAssertNil(Color(hex: "#ZZZZZZ"))
    }

    func testClockFormats() {
        var components = DateComponents()
        components.year = 2026; components.month = 10; components.day = 27
        components.hour = 21; components.minute = 5
        let date = Calendar(identifier: .gregorian).date(from: components)!
        XCTAssertEqual(ClockFormat.time(date, use24Hour: true), "21:05")
        XCTAssertEqual(ClockFormat.time(date, use24Hour: false), "9:05")
    }
}
