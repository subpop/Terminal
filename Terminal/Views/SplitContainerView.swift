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

struct SplitContainerView: View {
    let node: SplitNode
    @Environment(WorkspaceStore.self) var store
    @State private var containerSize: CGFloat = 800
    @State private var transientRatio: CGFloat?
    @State private var dragStartRatio: CGFloat?

    var body: some View {
        Group {
            switch node {
            case .leaf(let id):
                PaneView(paneID: id)

            case .split(let nid, let axis, let ratio, let first, let second):
                let displayRatio = transientRatio ?? ratio
                SplitLayout(axis: axis, ratio: displayRatio) {
                    SplitContainerView(node: first)
                    DividerHandle(
                        axis: axis,
                        containerSize: containerSize,
                        onDragChanged: { translation in
                            if dragStartRatio == nil { dragStartRatio = ratio }
                            let span = max(containerSize - 6, 1)
                            let delta = axis == .horizontal ? translation.width : translation.height
                            let next = (dragStartRatio ?? ratio) + delta / span
                            transientRatio = min(max(next, 0.12), 0.88)
                        },
                        onDragEnded: {
                            if let t = transientRatio {
                                store.setRatio(for: nid, ratio: t)
                            }
                            transientRatio = nil
                            dragStartRatio = nil
                        }
                    )
                    SplitContainerView(node: second)
                }
                .onGeometryChange(for: CGFloat.self, of: \.size.width) { width in
                    if axis == .horizontal { containerSize = width }
                }
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
                    if axis == .vertical { containerSize = height }
                }
            }
        }
    }
}

struct SplitLayout: Layout {
    var axis: SplitAxis
    var ratio: CGFloat
    private let dividerSize: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 3 else { return .zero }
        let proposed = proposal.replacingUnspecifiedDimensions()
        if axis == .horizontal {
            let totalWidth = proposed.width
            let firstWidth = max(0, (totalWidth - dividerSize) * ratio)
            let secondWidth = max(0, totalWidth - dividerSize - firstWidth)
            let firstSize = subviews[0].sizeThatFits(.init(width: firstWidth, height: proposed.height))
            let secondSize = subviews[2].sizeThatFits(.init(width: secondWidth, height: proposed.height))
            let height = max(firstSize.height, secondSize.height, proposed.height)
            return CGSize(width: totalWidth, height: height)
        } else {
            let totalHeight = proposed.height
            let firstHeight = max(0, (totalHeight - dividerSize) * ratio)
            let secondHeight = max(0, totalHeight - dividerSize - firstHeight)
            let firstSize = subviews[0].sizeThatFits(.init(width: proposed.width, height: firstHeight))
            let secondSize = subviews[2].sizeThatFits(.init(width: proposed.width, height: secondHeight))
            let width = max(firstSize.width, secondSize.width, proposed.width)
            return CGSize(width: width, height: totalHeight)
        }
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        if axis == .horizontal {
            let firstWidth = max(0, (bounds.width - dividerSize) * ratio)
            let secondWidth = max(0, bounds.width - dividerSize - firstWidth)
            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: firstWidth, height: bounds.height)
            )
            subviews[1].place(
                at: CGPoint(x: bounds.minX + firstWidth, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: dividerSize, height: bounds.height)
            )
            subviews[2].place(
                at: CGPoint(x: bounds.minX + firstWidth + dividerSize, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: secondWidth, height: bounds.height)
            )
        } else {
            let firstHeight = max(0, (bounds.height - dividerSize) * ratio)
            let secondHeight = max(0, bounds.height - dividerSize - firstHeight)
            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: firstHeight)
            )
            subviews[1].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY + firstHeight),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: dividerSize)
            )
            subviews[2].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY + firstHeight + dividerSize),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: secondHeight)
            )
        }
    }
}

private struct DividerHandle: View {
    let axis: SplitAxis
    let containerSize: CGFloat
    var onDragChanged: (CGSize) -> Void
    var onDragEnded: () -> Void
    @State private var hovering = false

    var body: some View {
        Rectangle()
            .fill(hovering ? Color.accentColor.opacity(0.6) : Color.clear)
            .frame(
                width: axis == .horizontal ? 6 : nil,
                height: axis == .vertical ? 6 : nil
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                self.hovering = hovering
                if hovering {
                    if axis == .horizontal { NSCursor.resizeLeftRight.push() }
                    else { NSCursor.resizeUpDown.push() }
                } else {
                    NSCursor.pop()
                }
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { value in onDragChanged(value.translation) }
                    .onEnded { _ in onDragEnded() }
            )
    }
}
