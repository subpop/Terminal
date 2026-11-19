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

@main
struct TerminalApp: App {
    @State private var settings = TerminalSettings()
    @State private var updater = SoftwareUpdater()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup(id: "terminal") {
            ContentView()
                .environment(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
                .onChange(of: settings.appearance, initial: true) { _, appearance in
                    updateDockIcon(for: appearance)
                }
        }
        .commands {
            WorkspaceCommands(settings: settings)
            SettingsCommands()
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(settings.defaultWindowSize)

        Window("Settings", id: "settings") {
            SettingsView(updater: updater)
                .environment(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
                .onChange(of: settings.appearance, initial: true) { _, appearance in
                    updateDockIcon(for: appearance)
                }
        }
        .defaultSize(width: 700, height: 440)
        .windowResizability(.contentMinSize)
    }

    private func updateDockIcon(for appearance: Appearance) {
        switch appearance {
        case .system: NSApp.applicationIconImage = nil
        case .light: NSApp.applicationIconImage = NSImage(named: "DockIconLight")
        case .dark: NSApp.applicationIconImage = NSImage(named: "DockIconDark")
        }
    }
}

struct SettingsCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                openWindow(id: "settings")
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

struct WorkspaceCommands: Commands {
    let settings: TerminalSettings
    @FocusedValue(\.workspaceStore) var store
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Tab") {
                newTab()
            }
            .keyboardShortcut("t", modifiers: .command)

            Divider()
            Button("Split Vertically") {
                guard let s = store, let fid = s.focusedPaneID else { return }
                s.split(over: fid, edge: .trailing)
            }.keyboardShortcut("d", modifiers: .command)
             .disabled(store == nil)

            Button("Split Horizontally") {
                guard let s = store, let fid = s.focusedPaneID else { return }
                s.split(over: fid, edge: .bottom)
            }.keyboardShortcut("d", modifiers: [.command, .shift])
             .disabled(store == nil)

            Button(store?.maximizedPaneID == nil ? "Expand Pane" : "Restore Pane") {
                guard let s = store, let fid = s.focusedPaneID else { return }
                s.toggleMaximizedPane(fid)
            }
            .disabled(store?.focusedPaneID == nil || (store?.root.leafCount ?? 0) <= 1)

            Button("Close Pane") {
                guard let s = store, let fid = s.focusedPaneID else { return }
                if s.root.leafCount > 1 {
                    s.requestClose(paneID: fid, askBeforeClosing: settings.askBeforeClosing,
                                   hasRunningCommand: LocalTerminalNSView.hasRunningCommand(for: fid))
                } else {
                    NSApp.keyWindow?.performClose(nil)
                }
            }.keyboardShortcut("w", modifiers: .command)
             .disabled(store == nil)
        }
        CommandGroup(after: .textEditing) {
            Button("Find…") { find(.showFindInterface) }
                .keyboardShortcut("f", modifiers: .command)
            Button("Find Next") { find(.nextMatch) }
                .keyboardShortcut("g", modifiers: .command)
            Button("Find Previous") { find(.previousMatch) }
                .keyboardShortcut("g", modifiers: [.command, .shift])
        }
        CommandGroup(before: .toolbar) {
            Button("Increase Font Size") {
                settings.fontSize = min(settings.fontSize + 1, TerminalSettings.maximumFontSize)
            }
            .keyboardShortcut("+", modifiers: .command)
            .disabled(store == nil || settings.fontSize >= TerminalSettings.maximumFontSize)

            Button("Decrease Font Size") {
                settings.fontSize = max(settings.fontSize - 1, TerminalSettings.minimumFontSize)
            }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(store == nil || settings.fontSize <= TerminalSettings.minimumFontSize)

            Button("Reset Font Size") {
                settings.fontSize = TerminalSettings.defaultFontSize
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(store == nil || settings.fontSize == TerminalSettings.defaultFontSize)

            Divider()
        }
        CommandGroup(after: .toolbar) {
            Button("Show Next Tab") { NSApp.keyWindow?.selectNextTab(nil) }
                .keyboardShortcut(.tab, modifiers: [.control])
                .disabled(store == nil)
            Button("Show Previous Tab") { NSApp.keyWindow?.selectPreviousTab(nil) }
                .keyboardShortcut(.tab, modifiers: [.control, .shift])
                .disabled(store == nil)
        }
    }

    private func newTab() {
        guard store != nil, let keyWindow = NSApp.keyWindow,
              keyWindow.tabbingIdentifier == "terminal" else {
            openWindow(id: "terminal")
            return
        }
        let existing = Set(NSApp.windows.map(\.windowNumber))
        openWindow(id: "terminal")
        Task { @MainActor in
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(50))
                if let newWindow = NSApp.windows.first(where: { !existing.contains($0.windowNumber) && $0.tabbingIdentifier == "terminal" }) {
                    keyWindow.addTabbedWindow(newWindow, ordered: .above)
                    newWindow.makeKeyAndOrderFront(nil)
                    return
                }
            }
        }
    }

    private func find(_ action: NSTextFinder.Action) {
        guard let paneID = store?.focusedPaneID else { return }
        LocalTerminalNSView.performFind(action, for: paneID)
    }
}
