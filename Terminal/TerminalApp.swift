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
    @FocusedValue(\.workspaceTabs) var tabs
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Tab") {
                newTab()
            }
            .keyboardShortcut("t", modifiers: .command)

            Button("Close Tab") {
                guard let tabs, let workspace = tabs.activeWorkspace else { return }
                WorkspaceTabActions.closeWorkspace(workspace.windowID, in: tabs, settings: settings)
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(tabs == nil)

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
                } else if let tabs {
                    WorkspaceTabActions.closeWorkspace(s.windowID, in: tabs, settings: settings)
                }
            }
            .disabled(store == nil)

            Divider()
            Button("Focus Pane to the Left") { focusPane(.leading) }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])
                .disabled(store?.adjacentPane(in: .leading) == nil)
            Button("Focus Pane to the Right") { focusPane(.trailing) }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
                .disabled(store?.adjacentPane(in: .trailing) == nil)
            Button("Focus Pane Above") { focusPane(.top) }
                .keyboardShortcut(.upArrow, modifiers: [.command, .shift])
                .disabled(store?.adjacentPane(in: .top) == nil)
            Button("Focus Pane Below") { focusPane(.bottom) }
                .keyboardShortcut(.downArrow, modifiers: [.command, .shift])
                .disabled(store?.adjacentPane(in: .bottom) == nil)
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
            Button("Previous Prompt") { jumpToPreviousPrompt() }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                .disabled(store?.focusedPaneID == nil)
            Button("Next Prompt") { jumpToNextPrompt() }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                .disabled(store?.focusedPaneID == nil)
            Button("Clear to Start") { clearScrollback() }
                .keyboardShortcut("k", modifiers: [.command, .control])
                .disabled(store?.focusedPaneID == nil)

            Divider()
            Button("Show Tab 1") { tabs?.selectWorkspace(at: 0) }
                .keyboardShortcut("1", modifiers: .command)
                .disabled((tabs?.workspaces.count ?? 0) < 1)
            Button("Show Tab 2") { tabs?.selectWorkspace(at: 1) }
                .keyboardShortcut("2", modifiers: .command)
                .disabled((tabs?.workspaces.count ?? 0) < 2)
            Button("Show Tab 3") { tabs?.selectWorkspace(at: 2) }
                .keyboardShortcut("3", modifiers: .command)
                .disabled((tabs?.workspaces.count ?? 0) < 3)
            Button("Show Tab 4") { tabs?.selectWorkspace(at: 3) }
                .keyboardShortcut("4", modifiers: .command)
                .disabled((tabs?.workspaces.count ?? 0) < 4)
            Button("Show Tab 5") { tabs?.selectWorkspace(at: 4) }
                .keyboardShortcut("5", modifiers: .command)
                .disabled((tabs?.workspaces.count ?? 0) < 5)
            Button("Show Tab 6") { tabs?.selectWorkspace(at: 5) }
                .keyboardShortcut("6", modifiers: .command)
                .disabled((tabs?.workspaces.count ?? 0) < 6)
            Button("Show Tab 7") { tabs?.selectWorkspace(at: 6) }
                .keyboardShortcut("7", modifiers: .command)
                .disabled((tabs?.workspaces.count ?? 0) < 7)
            Button("Show Tab 8") { tabs?.selectWorkspace(at: 7) }
                .keyboardShortcut("8", modifiers: .command)
                .disabled((tabs?.workspaces.count ?? 0) < 8)
            Button("Show Tab 9") { tabs?.selectWorkspace(at: 8) }
                .keyboardShortcut("9", modifiers: .command)
                .disabled((tabs?.workspaces.count ?? 0) < 9)

            Divider()
            Button("Show Next Tab") { tabs?.selectNextWorkspace() }
                .keyboardShortcut(.tab, modifiers: [.control])
                .disabled(tabs == nil || (tabs?.workspaces.count ?? 0) < 2)
            Button("Show Previous Tab") { tabs?.selectPreviousWorkspace() }
                .keyboardShortcut(.tab, modifiers: [.control, .shift])
                .disabled(tabs == nil || (tabs?.workspaces.count ?? 0) < 2)
        }
    }

    private func newTab() {
        guard let tabs else {
            openWindow(id: "terminal")
            return
        }
        tabs.addWorkspace()
    }

    private func focusPane(_ direction: DropEdge) {
        guard let paneID = store?.focusAdjacentPane(in: direction) else { return }
        Task { @MainActor in
            await Task.yield()
            LocalTerminalNSView.focus(paneID)
        }
    }

    private func find(_ action: NSTextFinder.Action) {
        guard let paneID = store?.focusedPaneID else { return }
        LocalTerminalNSView.performFind(action, for: paneID)
    }

    private func jumpToPreviousPrompt() {
        guard let paneID = store?.focusedPaneID else { return }
        LocalTerminalNSView.jumpToPreviousPrompt(for: paneID)
    }

    private func jumpToNextPrompt() {
        guard let paneID = store?.focusedPaneID else { return }
        LocalTerminalNSView.jumpToNextPrompt(for: paneID)
    }

    private func clearScrollback() {
        guard let paneID = store?.focusedPaneID else { return }
        LocalTerminalNSView.clearScrollback(for: paneID)
    }
}
