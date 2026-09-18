//
//  RenderSettings.swift
//
//  The pure value types the renderer works in. Split out from `Settings.swift`
//  deliberately: the render path, and the offline demo renderer in Tools/,
//  need these without pulling in SwiftUI, Combine or the @MainActor store.
//

import Foundation

enum CueIntensity: String, CaseIterable, Codable, Identifiable {
    case low, medium, high
    var id: String { rawValue }

    var displayName: String { localizedName(.current) }

    func localizedName(_ language: AppLanguage) -> String {
        switch self {
        case .low: L10n.t(.low, language)
        case .medium: L10n.t(.medium, language)
        case .high: L10n.t(.high, language)
        }
    }

    /// How hard vehicle acceleration drives the particle field, in points per
    /// second squared per g. This is what Intensity really controls.
    var flowGain: Double {
        switch self {
        case .low: 520
        case .medium: 900
        case .high: 1400
        }
    }
}

enum CueAppearance: String, CaseIterable, Codable, Identifiable {
    case automatic, light, dark
    var id: String { rawValue }

    var displayName: String { localizedName(.current) }

    func localizedName(_ language: AppLanguage) -> String {
        switch self {
        case .automatic: L10n.t(.followSystem, language)
        case .light: L10n.t(.darkDotsForLight, language)
        case .dark: L10n.t(.lightDotsForDark, language)
        }
    }
}

/// How the cue dots are coloured.
enum CueColorMode: String, CaseIterable, Codable, Identifiable {
    /// Black/white pair chosen for contrast against the background.
    case contrast
    /// Every particle uses the same user-picked colour.
    case solid
    /// Each particle gets a stable random hue.
    case random

    var id: String { rawValue }

    func localizedName(_ language: AppLanguage) -> String {
        switch self {
        case .contrast: L10n.t(.colorModeContrast, language)
        case .solid: L10n.t(.colorModeSolid, language)
        case .random: L10n.t(.colorModeRandom, language)
        }
    }
}

/// RGB 0…1 for the solid colour mode. Kept as plain Doubles so
/// `RenderSettings` stays Codable-free and DemoRenderer needs no AppKit.
struct CueSolidRGB: Equatable {
    var red: Double
    var green: Double
    var blue: Double

    static let `default` = CueSolidRGB(red: 0.20, green: 0.55, blue: 1.0)

    var simd: SIMD4<Float> {
        SIMD4(Float(red), Float(green), Float(blue), 1)
    }
}

/// Resolves the strong/halo pair drawn for each particle.
enum CueColoring {
    /// - Parameter darkDots: true → black strong / white halo (for light backgrounds).
    static func pair(mode: CueColorMode,
                     darkDots: Bool,
                     solid: CueSolidRGB,
                     seed: UInt32) -> (strong: SIMD4<Float>, halo: SIMD4<Float>) {
        switch mode {
        case .contrast:
            let strong: SIMD4<Float> = darkDots
                ? SIMD4(0, 0, 0, 1) : SIMD4(1, 1, 1, 1)
            let halo: SIMD4<Float> = darkDots
                ? SIMD4(1, 1, 1, 0.5) : SIMD4(0, 0, 0, 0.5)
            return (strong, halo)
        case .solid:
            let strong = solid.simd
            return (strong, contrastingHalo(for: strong))
        case .random:
            let strong = randomColor(seed: seed)
            return (strong, contrastingHalo(for: strong))
        }
    }

    /// White or black edge so a coloured dot stays readable on either background.
    static func contrastingHalo(for color: SIMD4<Float>) -> SIMD4<Float> {
        let luminance = 0.2126 * color.x + 0.7152 * color.y + 0.0722 * color.z
        return luminance > 0.55
            ? SIMD4(0, 0, 0, 0.5)
            : SIMD4(1, 1, 1, 0.5)
    }

    /// Stable HSV → RGB from a particle seed. Saturated, mid-bright colours.
    static func randomColor(seed: UInt32) -> SIMD4<Float> {
        // xorshift-ish mix so nearby lattice indices don't share a hue.
        var x = seed &* 0x9E3779B9
        x = (x ^ (x >> 16)) &* 0x85EBCA6B
        x = (x ^ (x >> 13)) &* 0xC2B2AE35
        x = x ^ (x >> 16)
        let hue = Float(x & 0xFFFF) / 65535.0
        let sat: Float = 0.72
        let val: Float = 0.92
        return hsv(hue, sat, val)
    }

    static func hsv(_ h: Float, _ s: Float, _ v: Float) -> SIMD4<Float> {
        let i = floor(h * 6)
        let f = h * 6 - i
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)
        switch Int(i) % 6 {
        case 0: return SIMD4(v, t, p, 1)
        case 1: return SIMD4(q, v, p, 1)
        case 2: return SIMD4(p, v, t, 1)
        case 3: return SIMD4(p, q, v, 1)
        case 4: return SIMD4(t, p, v, 1)
        default: return SIMD4(v, p, q, 1)
        }
    }
}

/// Immutable snapshot handed to the renderer. Copied once per settings change,
/// never read through an observable object at frame rate.
struct RenderSettings: Equatable {
    var dotDiameter: Double = 9
    var opacity: Double = 0.55
    var appearance: CueAppearance = .automatic
    var colorMode: CueColorMode = .contrast
    var solidColor: CueSolidRGB = .default
    var verticalCues: Bool = true
    var idleFadeEnabled: Bool = true
    /// Scales vehicle acceleration into the particle field's response.
    /// Points per second squared per g. See ParticleField.
    var flowGain: Double = 900
    /// How far in from the screen edge the cue reaches, in points. The middle
    /// is left clear because that is where you are trying to read.
    var peripherySize: Double = 240
}
