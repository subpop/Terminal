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

struct FocusedWorkspaceKey: FocusedValueKey {
    typealias Value = WorkspaceStore
}

struct FocusedWorkspaceTabsKey: FocusedValueKey {
    typealias Value = WorkspaceTabs
}

extension FocusedValues {
    var workspaceStore: WorkspaceStore? {
        get { self[FocusedWorkspaceKey.self] }
        set { self[FocusedWorkspaceKey.self] = newValue }
    }

    var workspaceTabs: WorkspaceTabs? {
        get { self[FocusedWorkspaceTabsKey.self] }
        set { self[FocusedWorkspaceTabsKey.self] = newValue }
    }
}
