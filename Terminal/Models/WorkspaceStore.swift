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

@Observable @MainActor
final class WorkspaceStore {
    var root: SplitNode
    var panes: [UUID: PaneModel]
    var focusedPaneID: UUID?
    var maximizedPaneID: UUID?
    var panePendingClose: UUID?
    var windowID: UUID

    // For NSWindow title sync
    var title: String {
        if let fid = focusedPaneID, let pane = panes[fid] {
            return pane.title
        }
        return panes.values.first?.title ?? "Terminal"
    }

    var currentDirectory: String {
        focusedPaneID.flatMap { panes[$0]?.currentDirectory } ?? FileManager.default.homeDirectoryForCurrentUser.path
    }

    var processName: String? {
        if let focusedPaneID, let pane = panes[focusedPaneID] {
            return pane.processName
        }
        return panes.values.first?.processName
    }

    init() {
        let initialPane = PaneModel(title: "Terminal")
        self.root = .leaf(id: initialPane.id)
        self.panes = [initialPane.id: initialPane]
        self.focusedPaneID = initialPane.id
        self.windowID = UUID()
    }

    // Create new pane and return its ID
    @discardableResult
    func createPane(title: String = "Terminal", initialDirectory: String? = nil) -> UUID {
        var pane = PaneModel(title: title)
        if let initialDirectory, !initialDirectory.isEmpty {
            pane.currentDirectory = initialDirectory
        }
        panes[pane.id] = pane
        return pane.id
    }

    func setTitle(_ title: String, for paneID: UUID) {
        guard var pane = panes[paneID] else { return }
        pane.title = title
        panes[paneID] = pane
    }

    func setProcessName(_ name: String?, for paneID: UUID) {
        guard var pane = panes[paneID], pane.processName != name else { return }
        pane.processName = name
        panes[paneID] = pane
    }

    func setCurrentDirectory(_ directory: String?, for paneID: UUID) {
        guard let directory, let url = URL(string: directory), url.isFileURL,
              var pane = panes[paneID] else { return }
        pane.currentDirectory = url.path
        pane.reportsCurrentDirectory = true
        panes[paneID] = pane
    }

    func refreshCurrentDirectoryFromProcess(_ path: String, for paneID: UUID) {
        guard !path.isEmpty, var pane = panes[paneID], !pane.reportsCurrentDirectory,
              pane.currentDirectory != path else { return }
        pane.currentDirectory = path
        panes[paneID] = pane
    }

    func setSSHSession(_ isSSHSession: Bool, for paneID: UUID) {
        guard var pane = panes[paneID], pane.isSSHSession != isSSHSession else { return }
        pane.isSSHSession = isSSHSession
        panes[paneID] = pane
    }

    func focus(_ paneID: UUID) {
        focusedPaneID = paneID
    }

    func adjacentPane(in direction: DropEdge) -> UUID? {
        guard let focusedPaneID else { return nil }
        return root.adjacentLeaf(to: focusedPaneID, in: direction)
    }

    @discardableResult
    func focusAdjacentPane(in direction: DropEdge) -> UUID? {
        guard let paneID = adjacentPane(in: direction) else { return nil }
        maximizedPaneID = nil
        focus(paneID)
        return paneID
    }

    func toggleMaximizedPane(_ paneID: UUID) {
        guard root.leafCount > 1, root.contains(leaf: paneID) else { return }
        maximizedPaneID = maximizedPaneID == paneID ? nil : paneID
        focusedPaneID = paneID
    }

    func markCompleted(paneID: UUID) {
        guard var pane = panes[paneID] else { return }
        pane.isCompleted = true
        panes[paneID] = pane
    }

    func hasRunningProcess(where isRunningCommand: (UUID) -> Bool) -> Bool {
        panes.values.contains { !$0.isCompleted && isRunningCommand($0.id) }
    }

    // MARK: - Split ops

    func split(over targetID: UUID, edge: DropEdge) {
        // If splitting leaf that doesn't exist, ignore
        guard root.contains(leaf: targetID) else { return }
        if edge == .center {
            // swap via DnD handled separately
            return
        }
        let inheritedDirectory = panes[targetID]?.currentDirectory
        let nid = createPane(initialDirectory: inheritedDirectory)
        root = root.splitting(leaf: targetID, direction: edge, newPaneID: nid)
        maximizedPaneID = nil
        focusedPaneID = nid
    }

    func close(paneID: UUID) {
        guard panes[paneID] != nil else { return }
        if maximizedPaneID == paneID || root.leafCount == 2 { maximizedPaneID = nil }
        if root.leafCount == 1, case .leaf(let id) = root, id == paneID {
            panes.removeValue(forKey: paneID)
            // Window will close; leave root as is to avoid empty until window dismisses
            return
        }
        if let newRoot = root.removing(leaf: paneID) {
            root = newRoot
        } else {
            // Fallback: create new pane
            let nid = createPane()
            root = .leaf(id: nid)
            focusedPaneID = nid
        }
        panes.removeValue(forKey: paneID)
        if focusedPaneID == paneID {
            focusedPaneID = root.leafIDs.first
        }
    }

    func requestClose(paneID: UUID, askBeforeClosing: Bool, hasRunningCommand: Bool) {
        guard root.leafCount > 1, let pane = panes[paneID] else { return }
        if askBeforeClosing && !pane.isCompleted && hasRunningCommand {
            panePendingClose = paneID
        } else {
            close(paneID: paneID)
        }
    }

    func swapPanes(_ a: UUID, _ b: UUID) {
        guard a != b, root.contains(leaf: a), root.contains(leaf: b) else { return }
        root = root.swapping(a, b)
    }

    func setRatio(for nodeID: UUID, ratio: CGFloat) {
        root = root.settingRatio(for: nodeID, to: ratio)
    }

    // Handle DnD: drop dragged pane onto target edge/center
    func handleDrop(draggedID: UUID, onto targetID: UUID, edge: DropEdge) {
        guard draggedID != targetID else { return }
        guard root.contains(leaf: draggedID), root.contains(leaf: targetID) else { return }

        if edge == .center {
            swapPanes(draggedID, targetID)
            focusedPaneID = draggedID
            return
        }

        // Remove dragged from its current location first
        let withoutDragged = root.removing(leaf: draggedID)
        // If removing dragged left empty (shouldn't happen with 2+ panes), bail
        guard let base = withoutDragged else { return }
        // Now split target within base tree
        // Need to re-insert dragged as new leaf adjacent to target
        root = base.splitting(leaf: targetID, direction: edge, newPaneID: draggedID)
        focusedPaneID = draggedID
    }

    // Cross-window: move pane from other store
    // Called on destination store after source has removed it
    func insertExternalPane(_ pane: PaneModel, onto targetID: UUID, edge: DropEdge) {
        panes[pane.id] = pane
        maximizedPaneID = nil
        if edge == .center {
            // Just insert via split with 50/50 and then swap? Simpler: split trailing
            root = root.splitting(leaf: targetID, direction: .trailing, newPaneID: pane.id)
        } else {
            root = root.splitting(leaf: targetID, direction: edge, newPaneID: pane.id)
        }
        focusedPaneID = pane.id
    }

    func extractPane(_ paneID: UUID) -> PaneModel? {
        guard let pane = panes[paneID] else { return nil }
        if maximizedPaneID == paneID || root.leafCount == 2 { maximizedPaneID = nil }
        if let newRoot = root.removing(leaf: paneID) {
            root = newRoot
        } else {
            // Last pane: create fresh one to keep window alive until closed
            let nid = createPane()
            root = .leaf(id: nid)
        }
        panes.removeValue(forKey: paneID)
        if focusedPaneID == paneID { focusedPaneID = root.leafIDs.first }
        return pane
    }
}
