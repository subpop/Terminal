// Copyright 2026 Link Dupont
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import AppKit
import SwiftUI
import SwiftTerm

enum Theme {
    static let defaultBackgroundIntensity = 1.0 / 3
    static let defaultPrimaryTint = SwiftUI.Color(red: 0.25, green: 0.50, blue: 0.95)
    static let tintOptions: [SwiftUI.Color] = [
        "F29F90", "EFC14E", "61D665", "40B2BF", "4080F2", "D39AEA"
    ].map { color(hex: $0, default: defaultPrimaryTint) }
    static let backgroundTintOptions = tintOptions.map { tint -> SwiftUI.Color in
        let rgb = NSColor(tint).usingColorSpace(.deviceRGB) ?? .systemTeal
        return SwiftUI.Color(nsColor: NSColor(calibratedHue: rgb.hueComponent,
                                              saturation: rgb.saturationComponent * 0.55,
                                              brightness: rgb.brightnessComponent * 0.65, alpha: 1))
    }
    static let defaultSecondaryTint = Color.secondary

    struct Colors {
        let foreground: NSColor
        let background: NSColor
        let caret: NSColor
        let selectionBackground: NSColor
        let ansi: [NSColor]
    }

    static func colors(for appearance: Appearance, primaryTint: SwiftUI.Color = defaultPrimaryTint,
                       secondaryTint: SwiftUI.Color = defaultSecondaryTint,
                       primarySaturation: Double = 1,
                       backgroundIntensity: Double = defaultBackgroundIntensity,
                       tintsBackground: Bool = false,
                       systemIsDark: Bool? = nil) -> Colors {
        let isDark: Bool
        if let s = systemIsDark { isDark = s }
        else { isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
        let useDark: Bool
        switch appearance {
        case .system: useDark = isDark
        case .light: useDark = false
        case .dark: useDark = true
        }

        let primary = saturated(primaryTint, by: primarySaturation)
        let secondary = NSColor(secondaryTint).usingColorSpace(.deviceRGB) ?? .systemTeal
        let base = useDark ? NSColor.black : .white
        let backgroundStrength = CGFloat(min(1, max(0, backgroundIntensity))) * (useDark ? 0.36 : 0.12)
        let background: NSColor
        if tintsBackground {
            background = base.blended(withFraction: backgroundStrength, of: secondary) ?? base
        } else {
            let systemAppearance = NSAppearance(named: useDark ? .darkAqua : .aqua) ?? NSApp.effectiveAppearance
            var resolved = NSColor.windowBackgroundColor
            systemAppearance.performAsCurrentDrawingAppearance {
                resolved = NSColor.windowBackgroundColor.usingColorSpace(.deviceRGB) ?? .windowBackgroundColor
            }
            background = resolved
        }
        let textBase = useDark ? NSColor.white : .black
        let secondaryText = textBase.blended(withFraction: 0.04, of: secondary) ?? textBase
        let foreground = secondaryText.blended(withFraction: 0.02, of: primary) ?? secondaryText
        let caret = contrast(primary, against: background) >= 4.5 ? primary : foreground

        func readable(_ color: NSColor) -> NSColor {
            var result = color
            for _ in 0..<40 where contrast(result, against: background) < 4.5 {
                result = result.blended(withFraction: 0.12, of: textBase) ?? result
            }
            return result
        }

        let ansi = SwiftTerm.Color.paleColors.enumerated().map { index, source -> NSColor in
            if [0, 7, 8, 15].contains(index) {
                let strength: CGFloat = switch index {
                case 0: useDark ? 0.55 : 0.70
                case 8: useDark ? 0.68 : 0.80
                case 7: 0.85
                default: 1
                }
                return readable(background.blended(withFraction: strength, of: foreground) ?? foreground)
            }

            let anchor = NSColor(srgbRed: CGFloat(source.red) / 65535,
                                 green: CGFloat(source.green) / 65535,
                                 blue: CGFloat(source.blue) / 65535, alpha: 1)
            // Keep warning and success colors recognizable; tint blues and purples more strongly.
            let warm = [1, 2, 3, 9, 10, 11].contains(index)
            let primaryMix = anchor.blended(withFraction: warm ? 0.04 : 0.16, of: primary) ?? anchor
            let result = primaryMix.blended(withFraction: warm ? 0.04 : 0.08, of: secondary) ?? primaryMix
            return readable(result)
        }

        return Colors(foreground: foreground, background: background, caret: caret,
                      selectionBackground: primary.withAlphaComponent(useDark ? 0.40 : 0.25), ansi: ansi)
    }

    static func saturated(_ tint: SwiftUI.Color, by amount: Double) -> NSColor {
        let rgb = NSColor(tint).usingColorSpace(.deviceRGB) ?? .systemBlue
        return NSColor(calibratedHue: rgb.hueComponent,
                       saturation: rgb.saturationComponent * CGFloat(min(1, max(0, amount))),
                       brightness: rgb.brightnessComponent, alpha: 1)
    }

    static func terminalColors(_ ansi: [NSColor]) -> [SwiftTerm.Color] {
        ansi.map { color in
            let rgb = color.usingColorSpace(.deviceRGB) ?? color
            return SwiftTerm.Color(red8: UInt16((rgb.redComponent * 255).rounded()),
                                   green8: UInt16((rgb.greenComponent * 255).rounded()),
                                   blue8: UInt16((rgb.blueComponent * 255).rounded()))
        }
    }

    static func hex(_ tint: SwiftUI.Color) -> String {
        let rgb = NSColor(tint).usingColorSpace(.deviceRGB) ?? .systemBlue
        func channel(_ value: CGFloat) -> Int { min(255, max(0, Int((value * 255).rounded()))) }
        let value = (channel(rgb.redComponent) << 16)
            | (channel(rgb.greenComponent) << 8)
            | channel(rgb.blueComponent)
        let digits = String(value, radix: 16, uppercase: true)
        return String(repeating: "0", count: 6 - digits.count) + digits
    }

    static func color(hex: String?, default fallback: SwiftUI.Color) -> SwiftUI.Color {
        guard let hex, hex.count == 6, let value = UInt32(hex, radix: 16) else { return fallback }
        return SwiftUI.Color(.sRGB, red: Double((value >> 16) & 0xFF) / 255,
                             green: Double((value >> 8) & 0xFF) / 255,
                             blue: Double(value & 0xFF) / 255, opacity: 1)
    }

    static func contrast(_ first: NSColor, against second: NSColor) -> CGFloat {
        func luminance(_ color: NSColor) -> CGFloat {
            let rgb = color.usingColorSpace(.deviceRGB) ?? color
            func linear(_ value: CGFloat) -> CGFloat {
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent)
                + 0.0722 * linear(rgb.blueComponent)
        }
        let a = luminance(first)
        let b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
