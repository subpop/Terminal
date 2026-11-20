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

struct ContentView: View {
    @Environment(TerminalSettings.self) private var settings
    @State private var tabs = WorkspaceTabs()

    var body: some View {
        VStack(spacing: 0) {
            if tabs.workspaces.count > 1 {
                WorkspaceTabBarView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            WorkspaceWindowView()
                .frame(minWidth: 640, minHeight: 400)
        }
        .animation(.snappy(duration: 0.24), value: tabs.workspaces.count)
        .environment(tabs)
        .environment(settings)
        .focusedSceneValue(\.workspaceTabs, tabs)
    }
}

#Preview {
    ContentView()
        .environment(TerminalSettings())
}
