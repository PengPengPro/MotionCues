//
//  CueColoringTests.swift
//

import XCTest
import simd
@testable import MotionCues

final class CueColoringTests: XCTestCase {
    func testContrastDarkDotsAreBlack() {
        let pair = CueColoring.pair(mode: .contrast, darkDots: true,
                                    solid: .default, seed: 1)
        XCTAssertEqual(pair.strong.x, 0, accuracy: 0.001)
        XCTAssertEqual(pair.strong.y, 0, accuracy: 0.001)
        XCTAssertEqual(pair.strong.z, 0, accuracy: 0.001)
        XCTAssertGreaterThan(pair.halo.x, 0.9)
    }

    func testContrastLightDotsAreWhite() {
        let pair = CueColoring.pair(mode: .contrast, darkDots: false,
                                    solid: .default, seed: 1)
        XCTAssertGreaterThan(pair.strong.x, 0.9)
        XCTAssertEqual(pair.halo.x, 0, accuracy: 0.001)
    }

    func testSolidUsesPickedColour() {
        let solid = CueSolidRGB(red: 1, green: 0, blue: 0)
        let pair = CueColoring.pair(mode: .solid, darkDots: true,
                                    solid: solid, seed: 99)
        XCTAssertEqual(pair.strong.x, 1, accuracy: 0.001)
        XCTAssertEqual(pair.strong.y, 0, accuracy: 0.001)
        XCTAssertEqual(pair.strong.z, 0, accuracy: 0.001)
    }

    func testRandomIsStablePerSeed() {
        let a = CueColoring.randomColor(seed: 42)
        let b = CueColoring.randomColor(seed: 42)
        let c = CueColoring.randomColor(seed: 43)
        XCTAssertEqual(a.x, b.x, accuracy: 0.0001)
        XCTAssertEqual(a.y, b.y, accuracy: 0.0001)
        let distance = simd_distance(SIMD3(a.x, a.y, a.z), SIMD3(c.x, c.y, c.z))
        XCTAssertGreaterThan(distance, 0.05)
    }

    func testBrightColourGetsDarkHalo() {
        let white = SIMD4<Float>(1, 1, 1, 1)
        let halo = CueColoring.contrastingHalo(for: white)
        XCTAssertEqual(halo.x, 0, accuracy: 0.001)
    }

    @MainActor
    func testColorModePersistsInSettings() {
        let suite = "CueColoringTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(defaults: defaults)
        settings.colorMode = .random
        settings.solidRed = 0.1
        settings.solidGreen = 0.2
        settings.solidBlue = 0.3

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.colorMode, .random)
        XCTAssertEqual(reloaded.solidRed, 0.1, accuracy: 0.0001)
        XCTAssertEqual(reloaded.snapshot().colorMode, .random)
        XCTAssertEqual(reloaded.snapshot().solidColor.blue, 0.3, accuracy: 0.0001)
    }
}
