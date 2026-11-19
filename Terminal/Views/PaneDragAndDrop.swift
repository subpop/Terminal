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


import AppKit
import SwiftUI

private enum PanePasteboard {
    static let type = NSPasteboard.PasteboardType("app.subpop.Terminal.pane")

    static func read(from pasteboard: NSPasteboard) -> (windowID: UUID, paneID: UUID)? {
        guard let value = pasteboard.string(forType: type) else { return nil }
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let windowID = UUID(uuidString: String(parts[0])),
              let paneID = UUID(uuidString: String(parts[1])) else { return nil }
        return (windowID, paneID)
    }
}

struct PaneDragHandle: NSViewRepresentable {
    let paneID: UUID
    let title: String
    let isSSHSession: Bool
    let textColor: NSColor
    let store: WorkspaceStore

    func makeNSView(context: Context) -> PaneDragHandleView {
        PaneDragHandleView(paneID: paneID, store: store)
    }

    func updateNSView(_ view: PaneDragHandleView, context: Context) {
        view.label.stringValue = title
        view.label.textColor = textColor
        view.icon.image = NSImage(systemSymbolName: isSSHSession ? "globe" : "terminal",
                                  accessibilityDescription: isSSHSession ? "SSH session" : "Local shell")
        view.icon.contentTintColor = textColor
    }
}

final class PaneDragHandleView: NSView, NSDraggingSource {
    let paneID: UUID
    let store: WorkspaceStore
    let label = NSTextField(labelWithString: "")
    let icon = NSImageView()
    private var dragStart: NSPoint?
    private var isDragging = false

    init(paneID: UUID, store: WorkspaceStore) {
        self.paneID = paneID
        self.store = store
        super.init(frame: .zero)
        label.font = .preferredFont(forTextStyle: .body)
        label.lineBreakMode = .byTruncatingMiddle
        icon.imageScaling = .scaleProportionallyDown
        addSubview(icon)
        addSubview(label)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        icon.frame = NSRect(x: 0, y: (bounds.height - 16) / 2, width: 16, height: 16)
        let labelHeight = label.fittingSize.height
        label.frame = NSRect(x: 22, y: (bounds.height - labelHeight) / 2,
                             width: max(bounds.width - 22, 0), height: labelHeight)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        store.focus(paneID)
        dragStart = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isDragging, let dragStart else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard hypot(point.x - dragStart.x, point.y - dragStart.y) >= 3 else { return }

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString("\(store.windowID.uuidString):\(paneID.uuidString)", forType: PanePasteboard.type)
        let item = NSDraggingItem(pasteboardWriter: pasteboardItem)
        let frame = NSRect(x: 0, y: 0, width: min(bounds.width, 220), height: bounds.height)
        let image = NSImage(size: frame.size)
        if let bitmap = bitmapImageRepForCachingDisplay(in: frame) {
            cacheDisplay(in: frame, to: bitmap)
            image.addRepresentation(bitmap)
        }
        item.setDraggingFrame(frame, contents: image)

        isDragging = true
        WorkspaceRegistry.shared.draggingPaneID = paneID
        beginDraggingSession(with: [item], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .move
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        isDragging = false
        dragStart = nil
        WorkspaceRegistry.shared.draggingPaneID = nil
    }
}

struct PaneDropTarget: NSViewRepresentable {
    let paneID: UUID
    let store: WorkspaceStore

    func makeNSView(context: Context) -> PaneDropTargetView {
        PaneDropTargetView(paneID: paneID, store: store)
    }

    func updateNSView(_ view: PaneDropTargetView, context: Context) {
        view.isDragActive = WorkspaceRegistry.shared.draggingPaneID != nil &&
            WorkspaceRegistry.shared.draggingPaneID != paneID
    }
}

final class PaneDropTargetView: NSView {
    let paneID: UUID
    let store: WorkspaceStore
    var isDragActive = false { didSet { needsDisplay = true } }
    private var highlightedEdge: DropEdge? { didSet { needsDisplay = true } }

    init(paneID: UUID, store: WorkspaceStore) {
        self.paneID = paneID
        self.store = store
        super.init(frame: .zero)
        registerForDraggedTypes([PanePasteboard.type])
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard WorkspaceRegistry.shared.draggingPaneID != nil,
              WorkspaceRegistry.shared.draggingPaneID != paneID else { return nil }
        return super.hitTest(point)
    }

    static func edge(at point: CGPoint, in bounds: CGRect) -> DropEdge? {
        guard bounds.contains(point) else { return nil }
        let x = (point.x - bounds.minX) / bounds.width
        let y = (point.y - bounds.minY) / bounds.height
        if x < 0.25 { return .leading }
        if x > 0.75 { return .trailing }
        if y < 0.25 { return .top }
        if y > 0.75 { return .bottom }
        return .center
    }

    private func validDrag(_ sender: NSDraggingInfo) -> (windowID: UUID, paneID: UUID)? {
        guard let payload = PanePasteboard.read(from: sender.draggingPasteboard),
              WorkspaceRegistry.shared.draggingPaneID == payload.paneID,
              payload.paneID != paneID,
              let source = WorkspaceRegistry.shared.store(for: payload.windowID),
              source.panes[payload.paneID] != nil else { return nil }
        return payload
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        draggingUpdated(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard validDrag(sender) != nil else { highlightedEdge = nil; return [] }
        highlightedEdge = Self.edge(at: convert(sender.draggingLocation, from: nil), in: bounds)
        return highlightedEdge == nil ? [] : .move
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        highlightedEdge = nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let payload = validDrag(sender),
              let edge = Self.edge(at: convert(sender.draggingLocation, from: nil), in: bounds) else { return false }
        if payload.windowID == store.windowID {
            store.handleDrop(draggedID: payload.paneID, onto: paneID, edge: edge)
        } else {
            WorkspaceRegistry.shared.movePane(paneID: payload.paneID, from: payload.windowID,
                                              to: store, targetID: paneID, edge: edge)
        }
        highlightedEdge = nil
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.cgContext.clear(dirtyRect)
        guard isDragActive else { return }
        let accent = NSColor.controlAccentColor
        let zones: [(DropEdge, CGRect)] = [
            (.leading, CGRect(x: 0, y: 0, width: bounds.width * 0.25, height: bounds.height)),
            (.trailing, CGRect(x: bounds.width * 0.75, y: 0, width: bounds.width * 0.25, height: bounds.height)),
            (.top, CGRect(x: bounds.width * 0.25, y: 0, width: bounds.width * 0.5, height: bounds.height * 0.25)),
            (.bottom, CGRect(x: bounds.width * 0.25, y: bounds.height * 0.75, width: bounds.width * 0.5, height: bounds.height * 0.25)),
            (.center, CGRect(x: bounds.width * 0.25, y: bounds.height * 0.25,
                             width: bounds.width * 0.5, height: bounds.height * 0.5)),
        ]
        for (edge, frame) in zones {
            let selected = edge == highlightedEdge
            let shape = NSBezierPath(roundedRect: frame.insetBy(dx: 3, dy: 3), xRadius: 6, yRadius: 6)
            accent.withAlphaComponent(selected ? 0.35 : 0.09).setFill()
            shape.fill()
            accent.withAlphaComponent(selected ? 1 : 0.4).setStroke()
            shape.lineWidth = selected ? 2 : 1
            shape.stroke()
        }
    }
}
