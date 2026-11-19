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

struct PaneView: View {
    let paneID: UUID
    @Environment(WorkspaceStore.self) var store
    @Environment(TerminalSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    var pane: PaneModel? { store.panes[paneID] }
    var isFocused: Bool { store.focusedPaneID == paneID }

    private var isSplit: Bool { store.root.leafCount > 1 }

    var body: some View {
        VStack(spacing: 0) {
            if isSplit {
                PaneHeaderView(paneID: paneID, title: pane?.title ?? "Terminal")
            }
            LocalTerminalNSView(paneID: paneID,
                                deleteSendsControlH: settings.deleteSendsControlH,
                                optionAsMetaKey: settings.optionAsMetaKey,
                                bell: settings.bell)
                .clipped()
                .padding(4)
                .background(Color(nsColor: Theme.colors(for: settings.appearance,
                     primaryTint: settings.primaryTint, secondaryTint: settings.secondaryTint,
                     primarySaturation: settings.primaryTintSaturation,
                     backgroundIntensity: settings.backgroundIntensity,
                     tintsBackground: settings.tintsBackground,
                     systemIsDark: colorScheme == .dark).background))
        }
        .background(.background)
        .clipShape(.rect(cornerRadius: isSplit ? 10 : 0))
        .overlay {
            if isSplit {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isFocused ? settings.primaryTint.opacity(0.7) : Color.primary.opacity(0.08), lineWidth: isFocused ? 1.5 : 1)
            }
        }
        .overlay {
            PaneDropTarget(paneID: paneID, store: store)
                .allowsHitTesting(WorkspaceRegistry.shared.draggingPaneID != nil &&
                                  WorkspaceRegistry.shared.draggingPaneID != paneID)
        }
        .shadow(color: isSplit ? Color.black.opacity(0.12) : .clear, radius: 4, x: 0, y: 1)
        .onAppear { if store.focusedPaneID == nil { store.focus(paneID) } }
    }
}

struct PaneHeaderView: View {
    let paneID: UUID
    let title: String
    @Environment(WorkspaceStore.self) private var store
    @Environment(TerminalSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    private var colors: Theme.Colors {
        Theme.colors(for: settings.appearance, primaryTint: settings.primaryTint,
                     secondaryTint: settings.secondaryTint,
                     primarySaturation: settings.primaryTintSaturation,
                     backgroundIntensity: settings.backgroundIntensity,
                     tintsBackground: settings.tintsBackground,
                     systemIsDark: colorScheme == .dark)
    }

    var body: some View {
        HStack(spacing: 6) {
            PaneDragHandle(paneID: paneID, title: title,
                           isSSHSession: store.panes[paneID]?.isSSHSession == true,
                           textColor: colors.foreground, store: store)
                .frame(maxWidth: .infinity)
            Button("Split vertically", systemImage: "rectangle.split.2x1") {
                store.split(over: paneID, edge: .trailing)
            }
            .buttonStyle(.plain)
            .help("Split vertically (⌘D)")
            .labelStyle(.iconOnly)

            Button("Split horizontally", systemImage: "rectangle.split.1x2") {
                store.split(over: paneID, edge: .bottom)
            }
            .buttonStyle(.plain)
            .help("Split horizontally (⇧⌘D)")
            .labelStyle(.iconOnly)

            Button(store.maximizedPaneID == paneID ? "Restore pane" : "Expand pane",
                   systemImage: store.maximizedPaneID == paneID
                   ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                store.toggleMaximizedPane(paneID)
            }
            .buttonStyle(.plain)
            .help(store.maximizedPaneID == paneID ? "Restore pane layout" : "Fill window with pane")
            .labelStyle(.iconOnly)

            Button("Close pane", systemImage: "xmark") {
                store.requestClose(paneID: paneID, askBeforeClosing: settings.askBeforeClosing,
                                   hasRunningCommand: LocalTerminalNSView.hasRunningCommand(for: paneID))
            }
            .buttonStyle(.plain)
            .help("Close pane")
            .labelStyle(.iconOnly)
        }
        .foregroundStyle(Color(nsColor: colors.foreground))
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(Color(nsColor: colors.background))
        .accessibilityElement(children: .contain)
    }
}
