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


import SwiftUI
import SwiftTerm

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum ShellRunMode: String, CaseIterable, Identifiable {
    case defaultLoginShell, customCommand
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .defaultLoginShell: return "Default login shell"
        case .customCommand: return "Custom command"
        }
    }
}

enum ShellExitAction: String, CaseIterable, Identifiable {
    case closeIfClean, closeAlways, dontClose
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .closeIfClean: return "Close if shell exited cleanly"
        case .closeAlways: return "Close the window"
        case .dontClose: return "Don’t close the window"
        }
    }
}

enum AskBeforeClosingMode {
    static func migrate(from raw: String?) -> Bool {
        switch raw {
        case "always": return true
        case "never": return false
        case "onlyIfRunning", "Only when there is a running process": return true
        default: return true
        }
    }
}

enum TerminalCursorStyle: String, CaseIterable, Identifiable {
    case block, underline, bar
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .block: return "Block"
        case .underline: return "Underline"
        case .bar: return "Bar"
        }
    }
}

enum TitleLabelContent: String, CaseIterable, Identifiable {
    case terminalTitle, folderName, fullPath, processName, appName, custom, none

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .terminalTitle: return "Terminal title"
        case .folderName: return "Folder name"
        case .fullPath: return "Full path"
        case .processName: return "Process name"
        case .appName: return "App name"
        case .custom: return "Custom text"
        case .none: return "None"
        }
    }

    static var applicationName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Terminal"
    }

    func text(title: String, directory: String, processName: String? = nil, customText: String = "") -> String? {
        switch self {
        case .terminalTitle: return title
        case .folderName: return URL(fileURLWithPath: directory).lastPathComponent
        case .fullPath: return directory
        case .processName: return processName ?? title
        case .appName: return Self.applicationName
        case .custom: return customText.isEmpty ? nil : customText
        case .none: return nil
        }
    }
}

enum TerminalType: String, CaseIterable, Identifiable {
    case xterm256color = "xterm-256color"
    case xterm
    case vt100

    var id: String { rawValue }
    var processEnvironment: [String] {
        Terminal.getEnvironmentVariables(termName: rawValue, trueColor: self == .xterm256color)
    }
}

enum TerminalBell: String, CaseIterable, Identifiable {
    case none, sound, visual, soundAndVisual

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .none: return "None"
        case .sound: return "Sound"
        case .visual: return "Visual"
        case .soundAndVisual: return "Sound and visual"
        }
    }

    var swiftTermStyle: BellStyle { BellStyle(tagName: rawValue) ?? .sound }
}

@Observable @MainActor
final class TerminalSettings {
    static let defaultFontSize = 13.0
    static let minimumFontSize = 6.0
    static let maximumFontSize = 72.0

    var appearance: Appearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance) }
    }
    var primaryTint: SwiftUI.Color {
        didSet { UserDefaults.standard.set(Theme.hex(primaryTint), forKey: Keys.primaryTint) }
    }
    var primaryTintSaturation: Double {
        didSet { UserDefaults.standard.set(primaryTintSaturation, forKey: Keys.primaryTintSaturation) }
    }
    var secondaryTint: SwiftUI.Color {
        didSet { UserDefaults.standard.set(Theme.hex(secondaryTint), forKey: Keys.secondaryTint) }
    }
    var backgroundIntensity: Double {
        didSet { UserDefaults.standard.set(backgroundIntensity, forKey: Keys.backgroundIntensity) }
    }
    var tintsBackground: Bool {
        didSet { UserDefaults.standard.set(tintsBackground, forKey: Keys.tintsBackground) }
    }
    var shellRunMode: ShellRunMode {
        didSet { UserDefaults.standard.set(shellRunMode.rawValue, forKey: Keys.shellRunMode) }
    }
    var customCommand: String {
        didSet { UserDefaults.standard.set(customCommand, forKey: Keys.customCommand) }
    }
    var shellExitAction: ShellExitAction {
        didSet { UserDefaults.standard.set(shellExitAction.rawValue, forKey: Keys.shellExitAction) }
    }
    var askBeforeClosing: Bool {
        didSet { UserDefaults.standard.set(askBeforeClosing, forKey: Keys.askBeforeClosing) }
    }
    var fontName: String {
        didSet { UserDefaults.standard.set(fontName, forKey: Keys.fontName) }
    }
    var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: Keys.fontSize) }
    }
    var cursorStyle: TerminalCursorStyle {
        didSet { UserDefaults.standard.set(cursorStyle.rawValue, forKey: Keys.cursorStyle) }
    }
    var cursorBlink: Bool {
        didSet { UserDefaults.standard.set(cursorBlink, forKey: Keys.cursorBlink) }
    }
    var defaultCols: Int {
        didSet { UserDefaults.standard.set(defaultCols, forKey: Keys.defaultCols) }
    }
    var defaultRows: Int {
        didSet { UserDefaults.standard.set(defaultRows, forKey: Keys.defaultRows) }
    }
    var titleLabel: TitleLabelContent {
        didSet { UserDefaults.standard.set(titleLabel.rawValue, forKey: Keys.titleLabel) }
    }
    var subtitleLabel: TitleLabelContent {
        didSet { UserDefaults.standard.set(subtitleLabel.rawValue, forKey: Keys.subtitleLabel) }
    }
    var titleCustomText: String {
        didSet { UserDefaults.standard.set(titleCustomText, forKey: Keys.titleCustomText) }
    }
    var subtitleCustomText: String {
        didSet { UserDefaults.standard.set(subtitleCustomText, forKey: Keys.subtitleCustomText) }
    }
    var scrollbackLines: Int {
        didSet { UserDefaults.standard.set(scrollbackLines, forKey: Keys.scrollbackLines) }
    }
    var terminalType: TerminalType {
        didSet { UserDefaults.standard.set(terminalType.rawValue, forKey: Keys.terminalType) }
    }
    var deleteSendsControlH: Bool {
        didSet { UserDefaults.standard.set(deleteSendsControlH, forKey: Keys.deleteSendsControlH) }
    }
    var optionAsMetaKey: Bool {
        didSet { UserDefaults.standard.set(optionAsMetaKey, forKey: Keys.optionAsMetaKey) }
    }
    var bell: TerminalBell {
        didSet { UserDefaults.standard.set(bell.rawValue, forKey: Keys.bell) }
    }
    var enableOsc8Hyperlinks: Bool {
        didSet { UserDefaults.standard.set(enableOsc8Hyperlinks, forKey: Keys.enableOsc8Hyperlinks) }
    }
    var enableShellIntegration: Bool {
        didSet { UserDefaults.standard.set(enableShellIntegration, forKey: Keys.enableShellIntegration) }
    }
    private enum Keys {
        static let appearance = "appearance"
        static let primaryTint = "primaryTint"
        static let primaryTintSaturation = "primaryTintSaturation"
        static let secondaryTint = "secondaryTint"
        static let backgroundIntensity = "backgroundIntensity"
        static let tintsBackground = "tintsBackground"
        static let shellRunMode = "shellRunMode"
        static let customCommand = "customCommand"
        static let shellExitAction = "shellExitAction"
        static let askBeforeClosing = "askBeforeClosing"
        static let fontName = "fontName"
        static let fontSize = "fontSize"
        static let cursorStyle = "cursorStyle"
        static let cursorBlink = "cursorBlink"
        static let defaultCols = "defaultCols"
        static let defaultRows = "defaultRows"
        static let titleLabel = "titleLabel"
        static let subtitleLabel = "subtitleLabel"
        static let titleCustomText = "titleCustomText"
        static let subtitleCustomText = "subtitleCustomText"
        static let scrollbackLines = "scrollbackLines"
        static let terminalType = "terminalType"
        static let deleteSendsControlH = "deleteSendsControlH"
        static let optionAsMetaKey = "optionAsMetaKey"
        static let bell = "bell"
        static let enableOsc8Hyperlinks = "enableOsc8Hyperlinks"
        static let enableShellIntegration = "enableShellIntegration"
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Keys.appearance), let v = Appearance(rawValue: raw) {
            appearance = v
        } else {
            appearance = .system
        }
        primaryTint = Theme.color(hex: UserDefaults.standard.string(forKey: Keys.primaryTint),
                                  default: Theme.defaultPrimaryTint)
        primaryTintSaturation = UserDefaults.standard.object(forKey: Keys.primaryTintSaturation) as? Double ?? 1
        secondaryTint = Theme.color(hex: UserDefaults.standard.string(forKey: Keys.secondaryTint),
                                    default: Theme.defaultSecondaryTint)
        backgroundIntensity = UserDefaults.standard.object(forKey: Keys.backgroundIntensity) as? Double
            ?? Theme.defaultBackgroundIntensity
        tintsBackground = UserDefaults.standard.bool(forKey: Keys.tintsBackground)
        if let raw = UserDefaults.standard.string(forKey: Keys.shellRunMode), let v = ShellRunMode(rawValue: raw) {
            shellRunMode = v
        } else {
            shellRunMode = .defaultLoginShell
        }
        if let existing = UserDefaults.standard.string(forKey: Keys.customCommand), !existing.isEmpty {
            customCommand = existing
        } else {
            customCommand = Self.defaultShell()
        }
        if let raw = UserDefaults.standard.string(forKey: Keys.shellExitAction), let v = ShellExitAction(rawValue: raw) {
            shellExitAction = v
        } else {
            shellExitAction = .closeIfClean
        }
        if let stored = UserDefaults.standard.object(forKey: Keys.askBeforeClosing) {
            if let boolVal = stored as? Bool {
                askBeforeClosing = boolVal
            } else if let strVal = stored as? String {
                askBeforeClosing = AskBeforeClosingMode.migrate(from: strVal)
            } else {
                askBeforeClosing = true
            }
        } else {
            askBeforeClosing = true
        }
        fontName = UserDefaults.standard.string(forKey: Keys.fontName) ?? "SFMonoTerminal-Regular"
        let storedSize = UserDefaults.standard.double(forKey: Keys.fontSize)
        fontSize = storedSize > 0 ? storedSize : Self.defaultFontSize
        if let raw = UserDefaults.standard.string(forKey: Keys.cursorStyle), let v = TerminalCursorStyle(rawValue: raw) {
            cursorStyle = v
        } else {
            cursorStyle = .block
        }
        cursorBlink = UserDefaults.standard.object(forKey: Keys.cursorBlink) as? Bool ?? true
        let cols = UserDefaults.standard.integer(forKey: Keys.defaultCols)
        defaultCols = cols > 0 ? cols : 80
        let rows = UserDefaults.standard.integer(forKey: Keys.defaultRows)
        defaultRows = rows > 0 ? rows : 24
        titleLabel = UserDefaults.standard.string(forKey: Keys.titleLabel).flatMap(TitleLabelContent.init(rawValue:)) ?? .appName
        subtitleLabel = UserDefaults.standard.string(forKey: Keys.subtitleLabel).flatMap(TitleLabelContent.init(rawValue:)) ?? .terminalTitle
        titleCustomText = UserDefaults.standard.string(forKey: Keys.titleCustomText) ?? ""
        subtitleCustomText = UserDefaults.standard.string(forKey: Keys.subtitleCustomText) ?? ""
        let scrollback = UserDefaults.standard.integer(forKey: Keys.scrollbackLines)
        scrollbackLines = scrollback > 0 ? scrollback : 5000
        terminalType = UserDefaults.standard.string(forKey: Keys.terminalType).flatMap(TerminalType.init(rawValue:)) ?? .xterm256color
        deleteSendsControlH = UserDefaults.standard.object(forKey: Keys.deleteSendsControlH) as? Bool ?? false
        optionAsMetaKey = UserDefaults.standard.object(forKey: Keys.optionAsMetaKey) as? Bool ?? true
        bell = UserDefaults.standard.string(forKey: Keys.bell).flatMap(TerminalBell.init(rawValue:)) ?? .sound
        enableOsc8Hyperlinks = UserDefaults.standard.object(forKey: Keys.enableOsc8Hyperlinks) as? Bool ?? true
        enableShellIntegration = UserDefaults.standard.object(forKey: Keys.enableShellIntegration) as? Bool ?? true
    }

    static func defaultShell() -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"], !shell.isEmpty {
            return shell
        }
        if FileManager.default.fileExists(atPath: "/bin/zsh") { return "/bin/zsh" }
        return "/bin/bash"
    }

    var resolvedShell: ResolvedShell {
        switch shellRunMode {
        case .defaultLoginShell:
            let path = Self.defaultShell()
            let comp = (path as NSString).lastPathComponent
            return ResolvedShell(executable: path, args: [], execName: comp.isEmpty ? nil : "-\(comp)")
        case .customCommand:
            return ResolvedShell.parse(commandLine: customCommand)
        }
    }

    var swiftTermCursorStyle: CursorStyle {
        switch (cursorStyle, cursorBlink) {
        case (.block, true): return .blinkBlock
        case (.block, false): return .steadyBlock
        case (.underline, true): return .blinkUnderline
        case (.underline, false): return .steadyUnderline
        case (.bar, true): return .blinkBar
        case (.bar, false): return .steadyBar
        }
    }

    var terminalFont: NSFont {
        if let font = NSFont(name: fontName, size: CGFloat(fontSize)) {
            return font
        }
        return NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
    }

    var defaultWindowSize: CGSize {
        let font = terminalFont
        let cellWidth = font.advancement(forGlyph: font.glyph(withName: "W")).width
        let cellHeight = ceil(font.ascender + abs(font.descender) + font.leading)
        return CGSize(width: max(500, CGFloat(defaultCols) * cellWidth + 8),
                      height: max(300, CGFloat(defaultRows) * cellHeight + 8))
    }
}

struct ResolvedShell {
    let executable: String
    let args: [String]
    let execName: String?

    static func parse(commandLine: String) -> ResolvedShell {
        let trimmed = commandLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            let fallback = TerminalSettings.defaultShell()
            return ResolvedShell(executable: fallback, args: [], execName: nil)
        }
        // Simple shell split respecting single/double quotes
        var parts: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escaped = false
        for ch in trimmed {
            if escaped {
                current.append(ch)
                escaped = false
                continue
            }
            if ch == "\\" && !inSingle {
                escaped = true
                continue
            }
            if ch == "'" && !inDouble {
                inSingle.toggle()
                continue
            }
            if ch == "\"" && !inSingle {
                inDouble.toggle()
                continue
            }
            if ch == " " && !inSingle && !inDouble {
                if !current.isEmpty { parts.append(current); current = "" }
                continue
            }
            current.append(ch)
        }
        if !current.isEmpty { parts.append(current) }
        guard let exec = parts.first else {
            return ResolvedShell(executable: trimmed, args: [], execName: nil)
        }
        let args = Array(parts.dropFirst())
        return ResolvedShell(executable: exec, args: args, execName: nil)
    }
}
