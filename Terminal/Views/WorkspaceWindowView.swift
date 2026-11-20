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

struct WorkspaceWindowView: View {
    @Environment(WorkspaceTabs.self) private var tabs
    @Environment(TerminalSettings.self) private var settings

    private var activeWorkspace: WorkspaceStore? { tabs.activeWorkspace }

    private var windowTitle: String {
        guard let store = activeWorkspace else { return TitleLabelContent.applicationName }
        return settings.titleLabel.text(title: store.title, directory: store.currentDirectory,
                                        processName: store.processName, customText: settings.titleCustomText)
            ?? TitleLabelContent.applicationName
    }

    private var subtitle: String? {
        guard let store = activeWorkspace else { return nil }
        return settings.subtitleLabel.text(title: store.title, directory: store.currentDirectory,
                                           processName: store.processName, customText: settings.subtitleCustomText)
    }

    var body: some View {
        ZStack {
            ForEach(tabs.workspaces, id: \.windowID) { workspace in
                WorkspaceContentView(store: workspace)
                    .opacity(tabs.activeWorkspaceID == workspace.windowID ? 1 : 0)
                    .allowsHitTesting(tabs.activeWorkspaceID == workspace.windowID)
                    .accessibilityHidden(tabs.activeWorkspaceID != workspace.windowID)
                    .zIndex(tabs.activeWorkspaceID == workspace.windowID ? 1 : 0)
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .toolbar {
            if activeWorkspace != nil {
                ToolbarItem(placement: .navigation) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(windowTitle)
                            .font(subtitle == nil ? .title3 : .headline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .frame(maxWidth: 300, alignment: .leading)
                }
                .sharedBackgroundVisibility(.hidden)
            }

            ToolbarSpacer(.flexible)

            if let store = activeWorkspace {
                ToolbarItem(placement: .primaryAction) {
                    ControlGroup {
                        Button("Split vertically", systemImage: "rectangle.split.2x1") {
                            guard let paneID = store.focusedPaneID else { return }
                            store.split(over: paneID, edge: .trailing)
                        }
                        .help("Split vertically (⌘D)")
                        .disabled(store.focusedPaneID == nil)

                        Button("Split horizontally", systemImage: "rectangle.split.1x2") {
                            guard let paneID = store.focusedPaneID else { return }
                            store.split(over: paneID, edge: .bottom)
                        }
                        .help("Split horizontally (⇧⌘D)")
                        .disabled(store.focusedPaneID == nil)

                        Button(store.maximizedPaneID == nil ? "Expand pane" : "Restore pane",
                               systemImage: store.maximizedPaneID == nil
                               ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left") {
                            guard let paneID = store.focusedPaneID else { return }
                            store.toggleMaximizedPane(paneID)
                        }
                        .help(store.maximizedPaneID == nil ? "Fill window with pane" : "Restore pane layout")
                        .disabled(store.focusedPaneID == nil || store.root.leafCount <= 1)
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
        .windowToolbarFullScreenVisibility(.onHover)
        .toolbarBackground(.ultraThinMaterial, for: .windowToolbar)
        .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        .background(WindowAccessor { window in
            configureWindow(window)
            window.title = windowTitle
            window.identifier = NSUserInterfaceItemIdentifier(tabs.windowID.uuidString)
            window.tabbingMode = .disallowed
        })
        .onChange(of: windowTitle) { _, newTitle in
            NSApp.windows.first(where: { $0.identifier?.rawValue == tabs.windowID.uuidString })?.title = newTitle
        }
        .onChange(of: tabs.activeWorkspaceID) { _, _ in
            guard let paneID = activeWorkspace?.focusedPaneID else { return }
            Task { @MainActor in
                await Task.yield()
                LocalTerminalNSView.focus(paneID)
            }
        }
        .focusedSceneValue(\.workspaceStore, activeWorkspace)
    }

    private func configureWindow(_ window: NSWindow) {
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.tabbingMode = .disallowed
        NSWindow.allowsAutomaticWindowTabbing = false
        let delegate = WindowCloseDelegate(tabs: tabs, settings: settings)
        window.delegate = delegate
        objc_setAssociatedObject(window, &AssociatedKeys.delegate, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

private struct WorkspaceContentView: View {
    let store: WorkspaceStore
    @Environment(TerminalSettings.self) private var settings

    var body: some View {
        ZStack {
            if store.root.leafCount > 1 {
                Rectangle()
                    .fill(.ultraThickMaterial)
                    .ignoresSafeArea()
            }

            Group {
                if let paneID = store.maximizedPaneID {
                    PaneView(paneID: paneID)
                } else {
                    SplitContainerView(node: store.root)
                }
            }
            .padding(store.root.leafCount > 1 ? 8 : 0)
        }
        .environment(store)
        .frame(minWidth: 500, minHeight: 300)
        .alert("Close pane?", isPresented: Binding(
            get: { store.panePendingClose != nil },
            set: { if !$0 { store.panePendingClose = nil } }
        ), presenting: store.panePendingClose) { paneID in
            Button("Close Pane", role: .destructive) {
                store.close(paneID: paneID)
                store.panePendingClose = nil
            }
            Button("Cancel", role: .cancel) { store.panePendingClose = nil }
        } message: { _ in
            Text("A process is still running. Closing this pane will terminate it.")
        }
        .task {
            while !Task.isCancelled {
                for paneID in store.root.leafIDs {
                    if let path = LocalTerminalNSView.processCurrentDirectory(for: paneID) {
                        store.refreshCurrentDirectoryFromProcess(path, for: paneID)
                    }
                    store.setSSHSession(LocalTerminalNSView.isSSHSession(for: paneID), for: paneID)
                    store.setProcessName(LocalTerminalNSView.processName(for: paneID), for: paneID)
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

private enum AssociatedKeys { static var delegate = 0 }

private final class WindowCloseDelegate: NSObject, NSWindowDelegate {
    let tabs: WorkspaceTabs
    let settings: TerminalSettings

    init(tabs: WorkspaceTabs, settings: TerminalSettings) {
        self.tabs = tabs
        self.settings = settings
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if !settings.askBeforeClosing { return true }
        let hasRunningProcess = tabs.workspaces.contains {
            $0.hasRunningProcess(where: LocalTerminalNSView.hasRunningCommand)
        }
        return hasRunningProcess ? confirm(for: sender) : true
    }

    func windowWillClose(_ notification: Notification) {
        for workspace in tabs.workspaces {
            LocalTerminalNSView.terminateSessions(Array(workspace.panes.keys))
            WorkspaceRegistry.shared.unregister(windowID: workspace.windowID)
        }
    }

    private func confirm(for window: NSWindow) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Close window?"
        alert.informativeText = "Processes are still running. Closing will terminate them."
        alert.addButton(withTitle: "Close")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        return alert.runModal() == .alertFirstButtonReturn
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
}
