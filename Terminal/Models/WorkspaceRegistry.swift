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


import Foundation

/// Global registry for cross-window pane drag. Simple in-memory.
@Observable @MainActor
final class WorkspaceRegistry {
    static let shared = WorkspaceRegistry()
    var draggingPaneID: UUID?
    private var stores: [UUID: WorkspaceStore] = [:]

    func register(_ store: WorkspaceStore) {
        stores[store.windowID] = store
    }

    func unregister(windowID: UUID) {
        stores.removeValue(forKey: windowID)
    }

    func store(for windowID: UUID) -> WorkspaceStore? {
        stores[windowID]
    }

    func containsPane(_ paneID: UUID) -> Bool {
        stores.values.contains { $0.panes[paneID] != nil }
    }

    /// Move pane from source window to destination window
    func movePane(paneID: UUID, from sourceWindowID: UUID, to destStore: WorkspaceStore, targetID: UUID, edge: DropEdge) {
        guard let source = stores[sourceWindowID], source.windowID != destStore.windowID else {
            // Intra-window handled by WorkspaceStore.handleDrop
            return
        }
        guard let pane = source.extractPane(paneID) else { return }
        destStore.insertExternalPane(pane, onto: targetID, edge: edge)
    }
}
