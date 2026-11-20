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
import SwiftTerm

struct LocalTerminalNSView: NSViewRepresentable {
    let paneID: UUID
    let deleteSendsControlH: Bool
    let optionAsMetaKey: Bool
    let bell: TerminalBell
    @Environment(WorkspaceStore.self) var store
    @Environment(WorkspaceTabs.self) private var tabs
    @Environment(TerminalSettings.self) var settings
    @Environment(\.colorScheme) private var colorScheme

    private static var cache: [UUID: LocalProcessTerminalView] = [:]

    static func processCurrentDirectory(for paneID: UUID) -> String? {
        guard let terminal = cache[paneID] as? ConfirmingTerminalView,
              terminal.process.running, terminal.process.shellPid > 0 else { return nil }
        return processCurrentDirectory(for: terminal.process.shellPid)
    }

    static func processName(for paneID: UUID) -> String? {
        guard let terminal = cache[paneID] as? ConfirmingTerminalView,
              terminal.process.running, terminal.process.shellPid > 0 else { return nil }
        let foregroundGroup = tcgetpgrp(terminal.process.childfd)
        if foregroundGroup > 0, let name = processName(for: foregroundGroup) { return name }
        return processName(for: terminal.process.shellPid)
    }

    private static func processName(for pid: pid_t) -> String? {
        var name = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)
        let count = name.withUnsafeMutableBufferPointer {
            proc_name(pid, $0.baseAddress, UInt32($0.count))
        }
        guard count > 0 else { return nil }
        return String(decoding: name.prefix(while: { $0 != 0 }).map(UInt8.init(bitPattern:)), as: UTF8.self)
    }

    static func isSSHSession(for paneID: UUID) -> Bool {
        guard let terminal = cache[paneID] as? ConfirmingTerminalView,
              terminal.process.running, terminal.process.shellPid > 0 else { return false }
        let pid = terminal.process.shellPid
        if isSSHProcess(pid) { return true }

        var children = [pid_t](repeating: 0, count: 64)
        let count = children.withUnsafeMutableBufferPointer {
            proc_listchildpids(pid, $0.baseAddress, Int32($0.count * MemoryLayout<pid_t>.size))
        }
        return count > 0 && children.prefix(Int(count)).contains(where: isSSHProcess)
    }

    private static func isSSHProcess(_ pid: pid_t) -> Bool {
        var name = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)
        let count = name.withUnsafeMutableBufferPointer {
            proc_name(pid, $0.baseAddress, UInt32($0.count))
        }
        guard count > 0 else { return false }
        return String(decoding: name.prefix(while: { $0 != 0 }).map(UInt8.init(bitPattern:)), as: UTF8.self) == "ssh"
    }

    static func processCurrentDirectory(for pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, $0, size)
        }
        guard result == size else { return nil }
        return withUnsafeBytes(of: info.pvi_cdir.vip_path) {
            String(decoding: $0.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }

    static func performFind(_ action: NSTextFinder.Action, for paneID: UUID) {
        guard let terminal = cache[paneID] else { return }
        let item = NSMenuItem()
        item.tag = action.rawValue
        terminal.performTextFinderAction(item)
    }

    static func focus(_ paneID: UUID) {
        guard let terminal = cache[paneID] else { return }
        terminal.window?.makeFirstResponder(terminal)
    }

    static func terminateSessions(_ paneIDs: [UUID]) {
        for paneID in paneIDs {
            cache.removeValue(forKey: paneID)?.terminate()
        }
    }

    static func hasRunningCommand(for paneID: UUID) -> Bool {
        guard let terminal = cache[paneID] as? ConfirmingTerminalView,
              terminal.process.running else { return false }
        guard let shellExecutable = terminal.shellExecutable else { return true }
        let shellPID = terminal.process.shellPid
        guard shellPID > 0 else { return true }

        return hasRunningCommand(shellPID: shellPID, shellExecutable: shellExecutable)
    }

    static func hasRunningCommand(shellPID: pid_t, shellExecutable: String) -> Bool {
        var path = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard path.withUnsafeMutableBufferPointer({ proc_pidpath(shellPID, $0.baseAddress, UInt32($0.count)) }) > 0 else {
            return true
        }
        let processPath = String(decoding: path.prefix(while: { $0 != 0 }).map(UInt8.init(bitPattern:)), as: UTF8.self)
        guard URL(fileURLWithPath: processPath).lastPathComponent ==
                URL(fileURLWithPath: shellExecutable).lastPathComponent else { return true }

        var childPID: pid_t = 0
        return proc_listchildpids(shellPID, &childPID, Int32(MemoryLayout<pid_t>.size)) != 0
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(paneID: paneID, store: store, tabs: tabs, settings: settings)
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        if let cached = Self.cache[paneID] {
            cached.processDelegate = context.coordinator
            context.coordinator.terminal = cached
            applyAppearance(to: cached, coordinator: context.coordinator)
            for gr in cached.gestureRecognizers {
                if let click = gr as? NSClickGestureRecognizer {
                    click.target = context.coordinator
                    click.action = #selector(Coordinator.handleClick(_:))
                }
            }
            Task { @MainActor in
                cached.window?.makeFirstResponder(cached)
            }
            return cached
        }

        let options = TerminalOptions(
            cols: settings.defaultCols,
            rows: settings.defaultRows,
            termName: settings.terminalType.rawValue,
            cursorStyle: settings.swiftTermCursorStyle,
            scrollback: settings.scrollbackLines
        )
        let terminal = ConfirmingTerminalView(frame: .zero, options: options)
        terminal.font = settings.terminalFont
        applyAppearance(to: terminal, coordinator: context.coordinator)
        terminal.processDelegate = context.coordinator
        try? terminal.setUseMetal(true)

        let resolved = settings.resolvedShell
        let shellNames: Set<String> = ["sh", "bash", "zsh", "fish", "ksh", "csh", "tcsh"]
        if settings.shellRunMode == .defaultLoginShell ||
            shellNames.contains(URL(fileURLWithPath: resolved.executable).lastPathComponent) {
            terminal.shellExecutable = resolved.executable
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        terminal.startProcess(executable: resolved.executable, args: resolved.args,
                              environment: settings.terminalType.processEnvironment,
                              execName: resolved.execName, currentDirectory: home)

        context.coordinator.terminal = terminal
        Self.cache[paneID] = terminal

        let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        click.delaysPrimaryMouseButtonEvents = false
        terminal.addGestureRecognizer(click)

        Task { @MainActor in
            terminal.window?.makeFirstResponder(terminal)
        }

        return terminal
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        applyAppearance(to: nsView, coordinator: context.coordinator)
        context.coordinator.paneID = paneID
        context.coordinator.store = store
        context.coordinator.tabs = tabs
        context.coordinator.settings = settings
        context.coordinator.terminal = nsView
        if Self.cache[paneID] !== nsView {
            Self.cache[paneID] = nsView
        }
        nsView.processDelegate = context.coordinator
        // Apply cursor style live
        nsView.setCursorStyle(settings.swiftTermCursorStyle)
    }

    static func dismantleNSView(_ nsView: LocalProcessTerminalView, coordinator: Coordinator) {
        if Self.cache[coordinator.paneID] == nil { return }
        if coordinator.store.panes[coordinator.paneID] == nil &&
            !WorkspaceRegistry.shared.containsPane(coordinator.paneID) {
            Self.teardownMetalThenTerminate(nsView, paneID: coordinator.paneID)
        }
        coordinator.terminal = nil
    }

    private static func teardownMetalThenTerminate(_ view: LocalProcessTerminalView, paneID: UUID) {
        if view.isUsingMetalRenderer {
            view.terminate()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                Self.cache.removeValue(forKey: paneID)
            }
        } else {
            view.terminate()
            Self.cache.removeValue(forKey: paneID)
        }
    }

    private func applyAppearance(to view: LocalProcessTerminalView, coordinator: Coordinator) {
        let colors = Theme.colors(for: settings.appearance, primaryTint: settings.primaryTint,
                                   secondaryTint: settings.secondaryTint,
                                   primarySaturation: settings.primaryTintSaturation,
                                   backgroundIntensity: settings.backgroundIntensity,
                                   tintsBackground: settings.tintsBackground,
                                   systemIsDark: colorScheme == .dark)
        view.nativeForegroundColor = colors.foreground
        view.nativeBackgroundColor = colors.background
        view.caretColor = colors.caret
        view.selectedTextBackgroundColor = colors.selectionBackground
        let palette = Theme.terminalColors(colors.ansi)
        if coordinator.installedPalette != palette {
            view.installColors(palette)
            coordinator.installedPalette = palette
        }
        view.font = settings.terminalFont
        view.setCursorStyle(settings.swiftTermCursorStyle)
        view.backspaceSendsControlH = deleteSendsControlH
        view.optionAsMetaKey = optionAsMetaKey
        view.bellStyle = bell.swiftTermStyle
    }

    @MainActor
    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        var paneID: UUID
        var store: WorkspaceStore
        var tabs: WorkspaceTabs
        var settings: TerminalSettings
        weak var terminal: LocalProcessTerminalView?
        var installedPalette: [SwiftTerm.Color]?

        init(paneID: UUID, store: WorkspaceStore, tabs: WorkspaceTabs, settings: TerminalSettings) {
            self.paneID = paneID
            self.store = store
            self.tabs = tabs
            self.settings = settings
        }

        @objc func handleClick(_ sender: NSGestureRecognizer) {
            store.focus(paneID)
            if let t = terminal { t.window?.makeFirstResponder(t) }
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            store.setTitle(title, for: paneID)
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            store.setCurrentDirectory(directory, for: paneID)
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            let isClean = exitCode == 0
            switch settings.shellExitAction {
            case .closeAlways:
                store.close(paneID: paneID)
                if store.panes.isEmpty {
                    Task { @MainActor in WorkspaceTabActions.closeAfterProcessExit(store, in: tabs) }
                }
            case .closeIfClean:
                if isClean {
                    store.close(paneID: paneID)
                    if store.panes.isEmpty {
                        Task { @MainActor in WorkspaceTabActions.closeAfterProcessExit(store, in: tabs) }
                    }
                } else {
                    // Keep pane, show exit status
                    let code = exitCode.map { String($0) } ?? "?"
                    store.setTitle("Exited (\(code))", for: paneID)
                    store.markCompleted(paneID: paneID)
                    terminal?.feed(text: "\r\n[Process exited with code \(code)]\r\n")
                }
            case .dontClose:
                let code = exitCode.map { String($0) } ?? "?"
                store.setTitle("Completed", for: paneID)
                store.markCompleted(paneID: paneID)
                terminal?.feed(text: "\r\n[Process completed: \(code)]\r\n")
            }
        }

        func processFailedToStart(source: TerminalView, error: LocalProcessError) {
            store.setTitle("Failed: \(error)", for: paneID)
            store.markCompleted(paneID: paneID)
        }
    }
}

final class ConfirmingTerminalView: LocalProcessTerminalView {
    var shellExecutable: String?

    override func paste(_ sender: Any) {
        guard let text = NSPasteboard.general.string(forType: .string),
              text.contains(where: { $0.isNewline }), let window else {
            super.paste(sender)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Paste multiple lines?"
        alert.informativeText = "Pasted text may run commands in this terminal."
        alert.addButton(withTitle: "Paste")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.pasteText(text)
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    var onWindow: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        Task { @MainActor in
            if let w = v.window { onWindow(w) }
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            if let w = nsView.window { onWindow(w) }
        }
    }
}
