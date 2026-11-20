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
import SwiftUI
import Testing
import SwiftTerm
@testable import Terminal

@MainActor
struct WorkspaceStoreTests {
    @Test func dockIconVariantsAreDistinct() throws {
        let light = try #require(NSImage(named: "DockIconLight")?.tiffRepresentation)
        let dark = try #require(NSImage(named: "DockIconDark")?.tiffRepresentation)
        #expect(light != dark)
    }

    @Test func derivedPaletteKeepsANSIColorsReadable() throws {
        for appearance in [Appearance.light, .dark] {
            let colors = Theme.colors(for: appearance)
            #expect(colors.ansi.count == 16)
            #expect(Theme.terminalColors(colors.ansi).count == 16)
            #expect(Theme.contrast(colors.foreground, against: colors.background) >= 4.5)
            for index in 0..<16 {
                #expect(Theme.contrast(colors.ansi[index], against: colors.background) >= 4.5,
                        "\(appearance) ANSI \(index)")
            }
            let red = try #require(colors.ansi[1].usingColorSpace(.deviceRGB))
            let green = try #require(colors.ansi[2].usingColorSpace(.deviceRGB))
            #expect(red.redComponent > red.greenComponent)
            #expect(green.greenComponent > green.redComponent)
        }
    }

    @Test func tintsChangeDerivedANSIAndBackground() {
        let defaultColors = Theme.colors(for: .dark, tintsBackground: true)
        let alternate = Theme.colors(for: .dark, primaryTint: .purple, secondaryTint: .orange,
                                     tintsBackground: true)
        #expect(defaultColors.background != alternate.background)
        #expect(defaultColors.ansi[4] != alternate.ansi[4])
        #expect(Theme.colors(for: .light).background != defaultColors.background)
        let stored = Theme.hex(.init(.sRGB, red: 0.2, green: 0.4, blue: 0.6, opacity: 1))
        #expect(stored == "336699")
        #expect(Theme.hex(Theme.color(hex: stored, default: .black)) == stored)
    }

    @Test func extremeTintsStillProduceReadableANSIColors() {
        for appearance in [Appearance.light, .dark] {
            for (primary, secondary) in [(SwiftUI.Color.black, SwiftUI.Color.white),
                                         (.white, .black), (.red, .green)] {
                let colors = Theme.colors(for: appearance, primaryTint: primary, secondaryTint: secondary)
                for index in 0..<16 {
                    #expect(Theme.contrast(colors.ansi[index], against: colors.background) >= 4.5,
                            "\(appearance) ANSI \(index)")
                }
            }
        }
    }

    @Test func tintSaturationPreservesHueAndChangesPalette() {
        let vivid = Theme.saturated(.red, by: 1).usingColorSpace(.deviceRGB)
        let muted = Theme.saturated(.red, by: 0.5).usingColorSpace(.deviceRGB)
        let neutral = Theme.saturated(.red, by: 0).usingColorSpace(.deviceRGB)
        #expect((vivid?.saturationComponent ?? 0) > (muted?.saturationComponent ?? 0))
        #expect((muted?.saturationComponent ?? 0) > (neutral?.saturationComponent ?? 0))
        #expect(abs((muted?.hueComponent ?? 0) - (vivid?.hueComponent ?? 0)) < 0.01)

        let vividPalette = Theme.colors(for: .dark, primaryTint: .red, secondaryTint: .blue)
        let mutedPalette = Theme.colors(for: .dark, primaryTint: .red, secondaryTint: .blue,
                                        primarySaturation: 0)
        #expect(vividPalette.ansi[4] != mutedPalette.ansi[4])
        #expect(vividPalette.background == mutedPalette.background)
        for index in 0..<16 {
            #expect(Theme.contrast(mutedPalette.ansi[index], against: mutedPalette.background) >= 4.5)
        }
    }

    @Test func backgroundIntensityChangesSurfaceWithoutLosingContrast() {
        for appearance in [Appearance.light, .dark] {
            let neutral = Theme.colors(for: appearance, backgroundIntensity: 0, tintsBackground: true)
            let tinted = Theme.colors(for: appearance, backgroundIntensity: 1, tintsBackground: true)
            #expect(neutral.background != tinted.background)
            #expect(Theme.contrast(tinted.foreground, against: tinted.background) >= 4.5)
            for color in tinted.ansi {
                #expect(Theme.contrast(color, against: tinted.background) >= 4.5)
            }
        }

        let bright = Theme.colors(for: .dark, secondaryTint: .white, backgroundIntensity: 1,
                                  tintsBackground: true)
        #expect(Theme.contrast(bright.foreground, against: bright.background) >= 4.5)
        for color in bright.ansi {
            #expect(Theme.contrast(color, against: bright.background) >= 4.5)
        }
    }

    @Test func systemBackgroundIsDefaultAndTintSettingsRemainAvailable() throws {
        for (appearance, name) in [(Appearance.light, NSAppearance.Name.aqua),
                                   (.dark, .darkAqua)] {
            let system = Theme.colors(for: appearance)
            let systemAppearance = try #require(NSAppearance(named: name))
            var expected = NSColor.windowBackgroundColor
            systemAppearance.performAsCurrentDrawingAppearance {
                expected = NSColor.windowBackgroundColor.usingColorSpace(.deviceRGB) ?? .windowBackgroundColor
            }
            #expect(Theme.hex(Color(nsColor: system.background)) == Theme.hex(Color(nsColor: expected)))

            let otherTint = Theme.colors(for: appearance, secondaryTint: .orange, backgroundIntensity: 1)
            #expect(system.background == otherTint.background)
            #expect(system.ansi[4] != otherTint.ansi[4])

            let tinted = Theme.colors(for: appearance, secondaryTint: .orange,
                                      backgroundIntensity: 1, tintsBackground: true)
            #expect(tinted.background != system.background)
            #expect(Theme.contrast(system.foreground, against: system.background) >= 4.5)
            for color in system.ansi {
                #expect(Theme.contrast(color, against: system.background) >= 4.5)
            }
        }
    }

    @Test func primaryAndSecondaryBothInfluenceANSIColors() {
        let original = Theme.colors(for: .dark, primaryTint: .blue, secondaryTint: .teal)
        let changedPrimary = Theme.colors(for: .dark, primaryTint: .pink, secondaryTint: .teal)
        let changedSecondary = Theme.colors(for: .dark, primaryTint: .blue, secondaryTint: .orange)
        for index in [1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14] {
            #expect(original.ansi[index] != changedPrimary.ansi[index])
            #expect(original.ansi[index] != changedSecondary.ansi[index])
        }
    }

    @Test func titleAndSubtitleChoicesUseFocusedPaneInformation() {
        let directory = "/Users/link/My Projects"
        #expect(TitleLabelContent.terminalTitle.text(title: "vim", directory: directory) == "vim")
        #expect(TitleLabelContent.folderName.text(title: "vim", directory: directory) == "My Projects")
        #expect(TitleLabelContent.fullPath.text(title: "vim", directory: directory) == directory)
        #expect(TitleLabelContent.processName.text(title: "shell", directory: directory, processName: "vim") == "vim")
        #expect(TitleLabelContent.processName.text(title: "shell", directory: directory) == "shell")
        #expect(TitleLabelContent.appName.text(title: "vim", directory: directory) == TitleLabelContent.applicationName)
        #expect(TitleLabelContent.custom.text(title: "vim", directory: directory, customText: "My terminal") == "My terminal")
        #expect(TitleLabelContent.custom.text(title: "vim", directory: directory) == nil)
        #expect(TitleLabelContent.none.text(title: "vim", directory: directory) == nil)
    }

    @Test func processNameFollowsFocusedPane() throws {
        let store = WorkspaceStore()
        let first = try #require(store.focusedPaneID)
        store.setProcessName("zsh", for: first)
        store.split(over: first, edge: .trailing)
        let second = try #require(store.focusedPaneID)
        #expect(store.processName == nil)
        store.setProcessName("vim", for: second)
        #expect(store.processName == "vim")
        store.focus(first)
        #expect(store.processName == "zsh")
    }

    @Test func terminalTypesMatchChildEnvironment() {
        for type in TerminalType.allCases {
            let options = TerminalOptions(termName: type.rawValue)
            let environment = type.processEnvironment
            #expect(environment.contains("TERM=\(options.termName)"))
        }
        #expect(TerminalBell.visual.swiftTermStyle == .visual)
    }

    @Test func defaultWindowSizeFollowsColumnsAndRows() {
        let settings = TerminalSettings()
        let previousColumns = settings.defaultCols
        let previousRows = settings.defaultRows
        defer {
            settings.defaultCols = previousColumns
            settings.defaultRows = previousRows
        }

        settings.defaultCols = 80
        settings.defaultRows = 24
        let original = settings.defaultWindowSize
        settings.defaultCols = 120
        settings.defaultRows = 48
        let larger = settings.defaultWindowSize
        #expect(larger.width > original.width)
        #expect(larger.height > original.height)
    }

    @Test func currentDirectoryFollowsFocusedPane() throws {
        let store = WorkspaceStore()
        let first = try #require(store.focusedPaneID)
        #expect(store.currentDirectory == FileManager.default.homeDirectoryForCurrentUser.path)

        store.setCurrentDirectory("file://localhost/Users/link/My%20Projects", for: first)
        #expect(store.currentDirectory == "/Users/link/My Projects")

        store.split(over: first, edge: .trailing)
        let second = try #require(store.focusedPaneID)
        store.setCurrentDirectory("file://localhost/tmp", for: second)
        #expect(store.currentDirectory == "/tmp")

        store.focus(first)
        #expect(store.currentDirectory == "/Users/link/My Projects")
        store.setCurrentDirectory(nil, for: first)
        store.refreshCurrentDirectoryFromProcess("/tmp", for: first)
        #expect(store.currentDirectory == "/Users/link/My Projects")
    }

    @Test func localShellDirectoryUpdatesWithoutEscapeSequence() throws {
        let store = WorkspaceStore()
        let paneID = try #require(store.focusedPaneID)
        store.refreshCurrentDirectoryFromProcess("/tmp", for: paneID)
        #expect(store.currentDirectory == "/tmp")
        #expect(LocalTerminalNSView.processCurrentDirectory(for: getpid()) == FileManager.default.currentDirectoryPath)
    }

    @Test func sshStatusBelongsToItsPane() throws {
        let store = WorkspaceStore()
        let first = try #require(store.focusedPaneID)
        store.split(over: first, edge: .trailing)
        let second = try #require(store.focusedPaneID)

        store.setSSHSession(true, for: first)
        #expect(store.panes[first]?.isSSHSession == true)
        #expect(store.panes[second]?.isSSHSession == false)

        store.setSSHSession(false, for: first)
        #expect(store.panes[first]?.isSSHSession == false)
    }

    @Test func expandingPanePreservesSplitLayout() throws {
        let store = WorkspaceStore()
        let first = try #require(store.focusedPaneID)
        store.split(over: first, edge: .trailing)
        let second = try #require(store.focusedPaneID)
        store.setRatio(for: store.root.id, ratio: 0.35)
        let layout = store.root

        store.toggleMaximizedPane(first)
        #expect(store.maximizedPaneID == first)
        #expect(store.focusedPaneID == first)
        #expect(store.root == layout)

        store.toggleMaximizedPane(first)
        #expect(store.maximizedPaneID == nil)
        #expect(store.root == layout)
        #expect(store.panes[second] != nil)
    }

    @Test func splittingOrClosingAnExpandedPaneRestoresLayout() throws {
        let store = WorkspaceStore()
        let first = try #require(store.focusedPaneID)
        store.split(over: first, edge: .trailing)
        let second = try #require(store.focusedPaneID)

        store.toggleMaximizedPane(first)
        store.split(over: first, edge: .bottom)
        #expect(store.maximizedPaneID == nil)
        #expect(store.root.leafCount == 3)

        store.toggleMaximizedPane(second)
        store.close(paneID: second)
        #expect(store.maximizedPaneID == nil)
        #expect(store.root.leafCount == 2)
    }

    @Test func closingRunningPaneRequiresConfirmation() throws {
        let store = WorkspaceStore()
        let first = try #require(store.focusedPaneID)
        store.split(over: first, edge: .trailing)
        let second = try #require(store.focusedPaneID)

        store.requestClose(paneID: second, askBeforeClosing: true, hasRunningCommand: true)

        #expect(store.panePendingClose == second)
        #expect(store.panes[second] != nil)
        #expect(store.root.leafCount == 2)
    }

    @Test func completedPaneClosesWithoutConfirmation() throws {
        let store = WorkspaceStore()
        let first = try #require(store.focusedPaneID)
        store.split(over: first, edge: .bottom)
        let second = try #require(store.focusedPaneID)
        store.markCompleted(paneID: second)

        store.requestClose(paneID: second, askBeforeClosing: true, hasRunningCommand: true)

        #expect(store.panePendingClose == nil)
        #expect(store.panes[second] == nil)
        #expect(store.root.leafIDs == [first])
        #expect(store.focusedPaneID == first)
    }

    @Test func idleShellPaneClosesWithoutConfirmation() throws {
        let store = WorkspaceStore()
        let first = try #require(store.focusedPaneID)
        store.split(over: first, edge: .trailing)
        let second = try #require(store.focusedPaneID)

        store.requestClose(paneID: second, askBeforeClosing: true, hasRunningCommand: false)

        #expect(store.panePendingClose == nil)
        #expect(store.root.leafIDs == [first])
    }

    @Test func windowOnlyWarnsForActiveCommands() throws {
        let store = WorkspaceStore()
        let first = try #require(store.focusedPaneID)
        store.split(over: first, edge: .trailing)
        let second = try #require(store.focusedPaneID)

        #expect(!store.hasRunningProcess { _ in false })
        #expect(store.hasRunningProcess { $0 == second })
    }

    @Test func processCheckDistinguishesAnIdleProcessFromOneWithChildren() throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["30"]
        try child.run()
        defer {
            if child.isRunning { child.terminate() }
            child.waitUntilExit()
        }

        #expect(!LocalTerminalNSView.hasRunningCommand(shellPID: child.processIdentifier,
                                                       shellExecutable: "/bin/sleep"))
        let executable = try #require(Bundle.main.executableURL)
        #expect(LocalTerminalNSView.hasRunningCommand(shellPID: getpid(),
                                                      shellExecutable: executable.path))
    }

    @Test func dropZonesSelectEdgesAndCenter() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(PaneDropTargetView.edge(at: CGPoint(x: 10, y: 50), in: bounds) == .leading)
        #expect(PaneDropTargetView.edge(at: CGPoint(x: 90, y: 50), in: bounds) == .trailing)
        #expect(PaneDropTargetView.edge(at: CGPoint(x: 50, y: 10), in: bounds) == .top)
        #expect(PaneDropTargetView.edge(at: CGPoint(x: 50, y: 90), in: bounds) == .bottom)
        #expect(PaneDropTargetView.edge(at: CGPoint(x: 50, y: 50), in: bounds) == .center)
        #expect(PaneDropTargetView.edge(at: CGPoint(x: 110, y: 50), in: bounds) == nil)
    }

    @Test func draggingBetweenPanesReordersWithoutLosingSessions() throws {
        let store = WorkspaceStore()
        let first = try #require(store.focusedPaneID)
        store.split(over: first, edge: .trailing)
        let second = try #require(store.focusedPaneID)

        store.handleDrop(draggedID: second, onto: first, edge: .leading)

        #expect(store.root.leafIDs == [second, first])
        #expect(store.panes.keys.contains(second))
        #expect(store.focusedPaneID == second)
    }

    @Test func draggingBetweenWindowsTransfersPane() throws {
        let source = WorkspaceStore()
        let destination = WorkspaceStore()
        let draggedID = try #require(source.focusedPaneID)
        let targetID = try #require(destination.focusedPaneID)
        WorkspaceRegistry.shared.register(source)
        WorkspaceRegistry.shared.register(destination)
        defer {
            WorkspaceRegistry.shared.unregister(windowID: source.windowID)
            WorkspaceRegistry.shared.unregister(windowID: destination.windowID)
        }

        WorkspaceRegistry.shared.movePane(paneID: draggedID, from: source.windowID,
                                          to: destination, targetID: targetID, edge: .bottom)

        #expect(source.panes[draggedID] == nil)
        #expect(destination.root.leafIDs == [targetID, draggedID])
        #expect(destination.focusedPaneID == draggedID)
        #expect(WorkspaceRegistry.shared.containsPane(draggedID))
    }

    @Test func invalidSplitDoesNotCreateAnOrphanPane() {
        let store = WorkspaceStore()
        store.split(over: UUID(), edge: .trailing)

        #expect(store.panes.count == 1)
        #expect(store.root.leafCount == 1)
    }
}
