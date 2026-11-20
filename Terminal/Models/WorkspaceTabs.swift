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
final class WorkspaceTabs {
    let windowID = UUID()
    private(set) var workspaces: [WorkspaceStore]
    private(set) var activeWorkspaceID: UUID

    var activeWorkspace: WorkspaceStore? {
        workspaces.first { $0.windowID == activeWorkspaceID }
    }

    init() {
        let workspace = WorkspaceStore()
        workspaces = [workspace]
        activeWorkspaceID = workspace.windowID
        WorkspaceRegistry.shared.register(workspace)
    }

    @discardableResult
    func addWorkspace() -> WorkspaceStore {
        let workspace = WorkspaceStore()
        workspaces.append(workspace)
        activeWorkspaceID = workspace.windowID
        WorkspaceRegistry.shared.register(workspace)
        return workspace
    }

    func selectWorkspace(_ workspaceID: UUID) {
        guard workspaces.contains(where: { $0.windowID == workspaceID }) else { return }
        activeWorkspaceID = workspaceID
    }

    func selectNextWorkspace() {
        selectWorkspace(offset: 1)
    }

    func selectPreviousWorkspace() {
        selectWorkspace(offset: -1)
    }

    func moveWorkspace(_ workspaceID: UUID, before targetID: UUID) {
        guard workspaceID != targetID,
              let sourceIndex = workspaces.firstIndex(where: { $0.windowID == workspaceID }),
              workspaces.contains(where: { $0.windowID == targetID }) else { return }
        let workspace = workspaces.remove(at: sourceIndex)
        guard let targetIndex = workspaces.firstIndex(where: { $0.windowID == targetID }) else { return }
        workspaces.insert(workspace, at: targetIndex)
    }

    @discardableResult
    func removeWorkspace(_ workspaceID: UUID) -> WorkspaceStore? {
        guard workspaces.count > 1,
              let index = workspaces.firstIndex(where: { $0.windowID == workspaceID }) else { return nil }
        let workspace = workspaces.remove(at: index)
        WorkspaceRegistry.shared.unregister(windowID: workspace.windowID)
        if activeWorkspaceID == workspaceID {
            activeWorkspaceID = workspaces[min(index, workspaces.count - 1)].windowID
        }
        return workspace
    }

    private func selectWorkspace(offset: Int) {
        guard let currentIndex = workspaces.firstIndex(where: { $0.windowID == activeWorkspaceID }),
              !workspaces.isEmpty else { return }
        let nextIndex = (currentIndex + offset + workspaces.count) % workspaces.count
        activeWorkspaceID = workspaces[nextIndex].windowID
    }
}
