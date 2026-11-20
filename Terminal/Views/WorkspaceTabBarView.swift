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

struct WorkspaceTabBarView: View {
    @Environment(WorkspaceTabs.self) private var tabs
    @Environment(TerminalSettings.self) private var settings
    @State private var hoveredCloseWorkspaceID: UUID?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs.workspaces, id: \.windowID) { workspace in
                tab(for: workspace)
                    .frame(maxWidth: .infinity)
            }

            Button("New Tab", systemImage: "plus") {
                tabs.addWorkspace()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .help("New Tab (⌘T)")
            .padding(.horizontal, 8)
        }
        .frame(height: 38)
        .animation(.snappy(duration: 0.24), value: tabs.workspaces.map(\.windowID))
        .background(.bar)
    }

    private func tab(for workspace: WorkspaceStore) -> some View {
        let title = tabTitle(for: workspace)
        let subtitle = tabSubtitle(for: workspace) ?? title
        let index = tabs.workspaces.firstIndex(where: { $0.windowID == workspace.windowID })
        let shortcut = index.flatMap(tabShortcut(for:))
        let isSelected = tabs.activeWorkspaceID == workspace.windowID

        return HStack(spacing: 0) {
            Button {
                tabs.selectWorkspace(workspace.windowID)
            } label: {
                HStack(spacing: 8) {
                    Text(subtitle)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .layoutPriority(-1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let shortcut {
                        Text(shortcut)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 10)
                .padding(.trailing, 8)
                .frame(height: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(subtitle)
            .accessibilityHint("Switch to tab")
            .help(subtitle)

            Button("Close \(title)", systemImage: "xmark") {
                WorkspaceTabActions.closeWorkspace(workspace.windowID, in: tabs, settings: settings)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.caption2)
            .frame(width: 20, height: 20)
            .background {
                if hoveredCloseWorkspaceID == workspace.windowID {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.quaternary)
                }
            }
            .frame(width: 26, height: 34)
            .onHover { isHovered in
                hoveredCloseWorkspaceID = isHovered ? workspace.windowID : nil
            }
            .help("Close Tab")
        }
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 7)
                    .fill(.quaternary)
            }
        }
        .draggable(workspace.windowID.uuidString)
        .dropDestination(for: String.self) { values, _ in
            guard let value = values.first, let draggedID = UUID(uuidString: value) else { return false }
            withAnimation(.snappy(duration: 0.24)) {
                tabs.moveWorkspace(draggedID, before: workspace.windowID)
            }
            return true
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .opacity
        ))
        .accessibilityElement(children: .contain)
    }

    private func tabTitle(for workspace: WorkspaceStore) -> String {
        settings.titleLabel.text(title: workspace.title, directory: workspace.currentDirectory,
                                 processName: workspace.processName, customText: settings.titleCustomText)
            ?? TitleLabelContent.applicationName
    }

    private func tabSubtitle(for workspace: WorkspaceStore) -> String? {
        settings.subtitleLabel.text(title: workspace.title, directory: workspace.currentDirectory,
                                    processName: workspace.processName, customText: settings.subtitleCustomText)
    }

    private func tabShortcut(for index: Int) -> String? {
        guard index < 9 else { return nil }
        return "⌘\(index + 1)"
    }
}

@MainActor
enum WorkspaceTabActions {
    static func closeWorkspace(_ workspaceID: UUID, in tabs: WorkspaceTabs, settings: TerminalSettings) {
        guard let workspace = tabs.workspaces.first(where: { $0.windowID == workspaceID }) else { return }
        guard tabs.workspaces.count > 1 else {
            window(for: tabs)?.performClose(nil)
            return
        }

        if settings.askBeforeClosing,
           workspace.hasRunningProcess(where: LocalTerminalNSView.hasRunningCommand),
           !confirmClosingTab() {
            return
        }

        guard let removed = tabs.removeWorkspace(workspaceID) else { return }
        LocalTerminalNSView.terminateSessions(Array(removed.panes.keys))
    }

    static func closeAfterProcessExit(_ workspace: WorkspaceStore, in tabs: WorkspaceTabs) {
        guard tabs.workspaces.count > 1 else {
            window(for: tabs)?.performClose(nil)
            return
        }
        tabs.removeWorkspace(workspace.windowID)
    }

    private static func window(for tabs: WorkspaceTabs) -> NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue == tabs.windowID.uuidString }
    }

    private static func confirmClosingTab() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Close tab?"
        alert.informativeText = "A process is still running. Closing this tab will terminate it."
        alert.addButton(withTitle: "Close")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        return alert.runModal() == .alertFirstButtonReturn
    }
}
