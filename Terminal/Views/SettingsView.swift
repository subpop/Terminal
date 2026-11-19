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
import AppKit

struct SettingsView: View {
    let updater: SoftwareUpdater
    @State private var destination: SettingsDestination? = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $destination) {
                ForEach(SettingsDestination.allCases) { destination in
                    destination.label.tag(destination)
                }
            }
            .navigationTitle("Settings")
            .frame(minWidth: 170)
        } detail: {
            switch destination ?? .general {
            case .general:
                GeneralContent(updater: updater)
            case .shell:
                ShellSettingsContent()
            case .terminal:
                TerminalSettingsContent()
            }
        }
        .frame(minWidth: 700, minHeight: 440)
    }
}

private enum SettingsDestination: CaseIterable, Hashable, Identifiable {
    case general, shell, terminal

    var id: Self { self }

    var label: Label<Text, Image> {
        switch self {
        case .general: Label("General", systemImage: "gearshape")
        case .shell: Label("Shell", systemImage: "terminal")
        case .terminal: Label("Terminal", systemImage: "desktopcomputer")
        }
    }
}

private struct ShellSettingsContent: View {
    @Environment(TerminalSettings.self) var settings

    var body: some View {
        @Bindable var s = settings
        Form {
            Section {
                Picker("Run", selection: $s.shellRunMode) {
                    ForEach(ShellRunMode.allCases) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .pickerStyle(.menu)

                if settings.shellRunMode == .customCommand {
                    HStack {
                        Text("Command")
                        TextField("e.g. /bin/zsh -l", text: $s.customCommand)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                } else {
                    Text("Uses \(TerminalSettings.defaultShell()) as login shell.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Shell")
            } footer: {
                Text("Takes effect for new panes.")
                    .font(.caption)
            }

            Section("When the shell exits") {
                Picker("", selection: $s.shellExitAction) {
                    ForEach(ShellExitAction.allCases) { a in
                        Text(a.displayName).tag(a)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            Section {
                Toggle("Ask before closing window with running process", isOn: $s.askBeforeClosing)
            } header: {
                Text("Ask before closing")
            } footer: {
                Text("Shows a confirmation when a process is still running.")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

private struct GeneralContent: View {
    @Environment(TerminalSettings.self) var settings
    let updater: SoftwareUpdater

    var body: some View {
        @Bindable var s = settings
        Form {
            Section("Theme") {
                HStack(spacing: 12) {
                    Spacer()
                    ForEach(Appearance.allCases) { appearance in
                        AppearanceOption(appearance: appearance,
                                         isSelected: settings.appearance == appearance) {
                            settings.appearance = appearance
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Section {
                TintControl(title: "Foreground", value: $s.primaryTintSaturation, tint: $s.primaryTint,
                            options: Theme.tintOptions)
                Toggle("Tint background", isOn: $s.tintsBackground)
                if settings.tintsBackground {
                    TintControl(title: "Background", value: $s.backgroundIntensity, tint: $s.secondaryTint,
                                options: Theme.backgroundTintOptions)
                }

                HStack(spacing: 12) {
                    TerminalPalettePreview(isDark: false)
                    TerminalPalettePreview(isDark: true)
                }
            } footer: {
                Text("Uses the system window background unless tinting is enabled. Programs using true color retain their colors.")
            }

            Section("Text") {
                HStack {
                    Text("Font")
                    Spacer()
                    Text("\(settings.fontName) \(settings.fontSize, format: .number.precision(.fractionLength(0))) pt")
                        .foregroundStyle(.secondary)
                    Button("Choose…") { showFontPanel() }
                }
            }

            Section("Window and tabs") {
                Picker("Title", selection: $s.titleLabel) {
                    ForEach(TitleLabelContent.allCases.filter { $0 != .none }) { content in
                        Text(content.displayName).tag(content)
                    }
                }
                if settings.titleLabel == .custom {
                    TextField("Custom title", text: $s.titleCustomText)
                        .textFieldStyle(.roundedBorder)
                }
                Picker("Subtitle", selection: $s.subtitleLabel) {
                    ForEach(TitleLabelContent.allCases) { content in
                        Text(content.displayName).tag(content)
                    }
                }
                if settings.subtitleLabel == .custom {
                    TextField("Custom subtitle", text: $s.subtitleCustomText)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("Default size")
                    Spacer()
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("Columns")
                            TextField("", value: $s.defaultCols, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack(spacing: 4) {
                            Text("Rows")
                            TextField("", value: $s.defaultRows, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                Text("Size applies to new windows. Native tab titles follow the window title.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Cursor") {
                Picker("Style", selection: $s.cursorStyle) {
                    ForEach(TerminalCursorStyle.allCases) { c in
                        Text(c.displayName).tag(c)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Blink cursor", isOn: $s.cursorBlink)
            }

            Section("Updates") {
                Toggle(
                    "Automatically check for updates",
                    isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }
                    )
                )
                Button("Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func showFontPanel() {
        FontPanelCoordinator.shared.show(for: settings)
    }
}

private struct TerminalPalettePreview: View {
    let isDark: Bool
    @Environment(TerminalSettings.self) private var settings

    var body: some View {
        let colors = Theme.colors(for: isDark ? .dark : .light,
                                   primaryTint: settings.primaryTint, secondaryTint: settings.secondaryTint,
                                   primarySaturation: settings.primaryTintSaturation,
                                   backgroundIntensity: settings.backgroundIntensity,
                                   tintsBackground: settings.tintsBackground)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isDark ? "Dark" : "Light")
                Spacer()
                Text("~ %")
                Text("▌")
                    .foregroundStyle(Color(nsColor: colors.caret))
            }
            .font(.system(.caption, design: .monospaced))

            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<8, id: \.self) { column in
                        Circle()
                            .fill(Color(nsColor: colors.ansi[row * 8 + column]))
                            .frame(width: 14, height: 14)
                    }
                }
                .accessibilityHidden(true)
            }

            Text("Selected text")
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 3)
                .background(Color(nsColor: colors.selectionBackground))
        }
        .foregroundStyle(Color(nsColor: colors.foreground))
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .padding(8)
        .background(Color(nsColor: colors.background), in: .rect(cornerRadius: 6))
    }
}

private struct TintControl: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    @Binding var tint: Color
    let options: [Color]
    @State private var showingOptions = false

    var body: some View {
        HStack {
            Text(title)
            Slider(value: $value, in: 0...1)
                .tint(tint)
                .accessibilityLabel(Text(title))
            Button {
                showingOptions = true
            } label: {
                Capsule()
                    .fill(tint)
                    .frame(width: 44, height: 24)
                    .padding(4)
                    .background(showingOptions ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.08), in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(title))
            .accessibilityHint("Choose a tint color")
            .help("Choose tint color")
            .popover(isPresented: $showingOptions) {
                TintSwatchGrid(title: title, selected: tint, options: options) { choice in
                    tint = choice
                    showingOptions = false
                }
            }
        }
    }
}

private struct TintSwatchGrid: View {
    let title: LocalizedStringKey
    let selected: Color
    let options: [Color]
    let choose: (Color) -> Void

    private let columns = Array(repeating: GridItem(.fixed(40)), count: 6)
    private let names: [LocalizedStringKey] = [
        "Salmon", "Gold", "Green", "Teal", "Blue", "Violet"
    ]

    var body: some View {
        let selectedHex = Theme.hex(selected)
        VStack(spacing: 12) {
            Text(title).bold()
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(options.indices, id: \.self) { index in
                    let color = options[index]
                    let isSelected = Theme.hex(color) == selectedHex
                    Button {
                        choose(color)
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 32, height: 32)
                            .padding(4)
                            .overlay {
                                Circle()
                                    .strokeBorder(isSelected ? Color.primary : .clear, lineWidth: 2)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(names[index]))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .help(Text(names[index]))
                }
            }
        }
        .padding()
    }
}

private struct AppearanceOption: View {
    let appearance: Appearance
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                AppearanceThumbnail(appearance: appearance)
                    .clipShape(.rect(cornerRadius: 5))
                    .padding(2)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                    }

                Text(appearance.displayName)
                    .font(.callout)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appearance.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct AppearanceThumbnail: View {
    let appearance: Appearance
    private static let width: CGFloat = 112
    private static let height: CGFloat = 76

    var body: some View {
        switch appearance {
        case .system:
            HStack(spacing: 0) {
                MiniTerminalPreview(isDark: false)
                    .frame(width: Self.width, height: Self.height)
                    .frame(width: Self.width / 2, alignment: .leading)
                    .clipped()
                MiniTerminalPreview(isDark: true)
                    .frame(width: Self.width, height: Self.height)
                    .frame(width: Self.width / 2, alignment: .trailing)
                    .clipped()
            }
        case .light:
            MiniTerminalPreview(isDark: false)
                .frame(width: Self.width, height: Self.height)
        case .dark:
            MiniTerminalPreview(isDark: true)
                .frame(width: Self.width, height: Self.height)
        }
    }
}

private struct MiniTerminalPreview: View {
    let isDark: Bool
    @Environment(TerminalSettings.self) private var settings

    var body: some View {
        let colors = Theme.colors(for: isDark ? .dark : .light,
                                   primaryTint: settings.primaryTint, secondaryTint: settings.secondaryTint,
                                   primarySaturation: settings.primaryTintSaturation,
                                   backgroundIntensity: settings.backgroundIntensity,
                                   tintsBackground: settings.tintsBackground)

        VStack(spacing: 0) {
            HStack(spacing: 3) {
                Circle().fill(.red).frame(width: 5, height: 5)
                Circle().fill(.yellow).frame(width: 5, height: 5)
                Circle().fill(.green).frame(width: 5, height: 5)
                Spacer()
                Text("Terminal")
                    .font(.caption2)
                    .foregroundStyle(isDark ? .white : .black)
                Spacer()
            }
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(Color(white: isDark ? 0.2 : 0.92))

            VStack(alignment: .leading, spacing: 0) {
                Text("~ % ls")
                    .foregroundStyle(Color(nsColor: colors.foreground))
                Text("Documents")
                    .foregroundStyle(Color(nsColor: colors.ansi[4]))
                Text("~ % ▌")
                    .foregroundStyle(Color(nsColor: colors.ansi[2]))
            }
            .font(.caption2.monospaced())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(6)
            .background(Color(nsColor: colors.background))
        }
        .accessibilityHidden(true)
    }
}

private struct TerminalSettingsContent: View {
    @Environment(TerminalSettings.self) var settings

    var body: some View {
        @Bindable var s = settings
        Form {
            Section("Compatibility") {
                Picker("Declare terminal as", selection: $s.terminalType) {
                    ForEach(TerminalType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                Text("Sets TERM for new sessions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Input") {
                Toggle("Delete sends Control-H", isOn: $s.deleteSendsControlH)
                Toggle("Use Option as Meta key", isOn: $s.optionAsMetaKey)
            }

            Section("Bell") {
                Picker("Bell", selection: $s.bell) {
                    ForEach(TerminalBell.allCases) { bell in
                        Text(bell.displayName).tag(bell)
                    }
                }
            }

            Section("Scrollback") {
                Stepper(value: $s.scrollbackLines, in: 500...100_000, step: 500) {
                    Text("Retain \(settings.scrollbackLines, format: .number) lines")
                }
                Text("Applies to new sessions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

@MainActor
private final class FontPanelCoordinator: NSObject {
    static let shared = FontPanelCoordinator()
    private var settings: TerminalSettings?

    func show(for settings: TerminalSettings) {
        self.settings = settings
        NSFontManager.shared.setSelectedFont(settings.terminalFont, isMultiple: false)
        NSFontManager.shared.target = self
        NSFontManager.shared.action = #selector(changeFont(_:))
        NSFontManager.shared.orderFrontFontPanel(nil)
    }

    @objc func changeFont(_ sender: NSFontManager) {
        guard let settings else { return }
        if let font = sender.selectedFont {
            settings.fontName = font.fontName
            settings.fontSize = Double(font.pointSize)
        } else {
            let converted = sender.convert(settings.terminalFont)
            settings.fontName = converted.fontName
            settings.fontSize = Double(converted.pointSize)
        }
    }
}
