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


import CoreGraphics
import Foundation

indirect enum SplitNode: Identifiable, Equatable {
    case leaf(id: UUID)
    case split(id: UUID, axis: SplitAxis, ratio: CGFloat, first: SplitNode, second: SplitNode)

    var id: UUID {
        switch self {
        case .leaf(let id): return id
        case .split(let id, _, _, _, _): return id
        }
    }

    // MARK: - Queries

    var leafIDs: [UUID] {
        switch self {
        case .leaf(let id): return [id]
        case .split(_, _, _, let a, let b): return a.leafIDs + b.leafIDs
        }
    }

    var leafCount: Int {
        switch self {
        case .leaf: return 1
        case .split(_, _, _, let a, let b): return a.leafCount + b.leafCount
        }
    }

    func contains(leaf id: UUID) -> Bool {
        switch self {
        case .leaf(let lid): return lid == id
        case .split(_, _, _, let a, let b): return a.contains(leaf: id) || b.contains(leaf: id)
        }
    }

    func contains(node id: UUID) -> Bool {
        if self.id == id { return true }
        switch self {
        case .leaf: return false
        case .split(_, _, _, let a, let b): return a.contains(node: id) || b.contains(node: id)
        }
    }

    func adjacentLeaf(to leafID: UUID, in direction: DropEdge) -> UUID? {
        guard let origin = leafCenters(in: CGRect(x: 0, y: 0, width: 1, height: 1))
            .first(where: { $0.id == leafID })?.center else { return nil }

        let candidates = leafCenters(in: CGRect(x: 0, y: 0, width: 1, height: 1))
            .filter { $0.id != leafID }
            .compactMap { leaf -> (id: UUID, score: CGFloat)? in
                let dx = leaf.center.x - origin.x
                let dy = leaf.center.y - origin.y
                let primaryDistance: CGFloat
                let secondaryDistance: CGFloat
                switch direction {
                case .leading:
                    guard dx < 0 else { return nil }
                    primaryDistance = -dx
                    secondaryDistance = abs(dy)
                case .trailing:
                    guard dx > 0 else { return nil }
                    primaryDistance = dx
                    secondaryDistance = abs(dy)
                case .top:
                    guard dy < 0 else { return nil }
                    primaryDistance = -dy
                    secondaryDistance = abs(dx)
                case .bottom:
                    guard dy > 0 else { return nil }
                    primaryDistance = dy
                    secondaryDistance = abs(dx)
                case .center:
                    return nil
                }
                return (leaf.id, primaryDistance + secondaryDistance)
            }

        return candidates.min { $0.score < $1.score }?.id
    }

    private func leafCenters(in rect: CGRect) -> [(id: UUID, center: CGPoint)] {
        switch self {
        case .leaf(let id):
            return [(id, CGPoint(x: rect.midX, y: rect.midY))]
        case .split(_, let axis, let ratio, let first, let second):
            let firstRect: CGRect
            let secondRect: CGRect
            if axis == .horizontal {
                firstRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width * ratio, height: rect.height)
                secondRect = CGRect(x: firstRect.maxX, y: rect.minY, width: rect.width * (1 - ratio), height: rect.height)
            } else {
                firstRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * ratio)
                secondRect = CGRect(x: rect.minX, y: firstRect.maxY, width: rect.width, height: rect.height * (1 - ratio))
            }
            return first.leafCenters(in: firstRect) + second.leafCenters(in: secondRect)
        }
    }

    // MARK: - Mutations (pure, return new tree)

    /// Set ratio for split node with given id
    func settingRatio(for nodeID: UUID, to newRatio: CGFloat) -> SplitNode {
        switch self {
        case .leaf: return self
        case .split(let id, let axis, let ratio, let a, let b):
            if id == nodeID {
                let clamped = min(max(newRatio, 0.12), 0.88)
                return .split(id: id, axis: axis, ratio: clamped, first: a, second: b)
            }
            return .split(id: id, axis: axis, ratio: ratio,
                          first: a.settingRatio(for: nodeID, to: newRatio),
                          second: b.settingRatio(for: nodeID, to: newRatio))
        }
    }

    /// Replace leaf with a split containing target + new pane
    func splitting(leaf targetID: UUID, direction: DropEdge, newPaneID: UUID) -> SplitNode {
        switch self {
        case .leaf(let id):
            if id == targetID {
                let axis: SplitAxis
                let firstID: UUID
                let secondID: UUID
                switch direction {
                case .leading:
                    axis = .horizontal; firstID = newPaneID; secondID = targetID
                case .trailing:
                    axis = .horizontal; firstID = targetID; secondID = newPaneID
                case .top:
                    axis = .vertical; firstID = newPaneID; secondID = targetID
                case .bottom:
                    axis = .vertical; firstID = targetID; secondID = newPaneID
                case .center:
                    // center is swap, not split — caller handles
                    return self
                }
                return .split(id: UUID(), axis: axis, ratio: 0.5,
                              first: .leaf(id: firstID),
                              second: .leaf(id: secondID))
            }
            return self
        case .split(let id, let axis, let ratio, let a, let b):
            return .split(id: id, axis: axis, ratio: ratio,
                          first: a.splitting(leaf: targetID, direction: direction, newPaneID: newPaneID),
                          second: b.splitting(leaf: targetID, direction: direction, newPaneID: newPaneID))
        }
    }

    /// Remove leaf; collapse parent splits
    func removing(leaf targetID: UUID) -> SplitNode? {
        switch self {
        case .leaf(let id):
            if id == targetID { return nil }
            return self
        case .split(let id, let axis, let ratio, let a, let b):
            let newA = a.removing(leaf: targetID)
            let newB = b.removing(leaf: targetID)
            // If one side removed entirely, promote the other
            if newA == nil && newB == nil { return nil }
            if newA == nil { return newB }
            if newB == nil { return newA }
            // If neither contains target, unchanged
            // But if both present, rebuild
            return .split(id: id, axis: axis, ratio: ratio, first: newA!, second: newB!)
        }
    }

    /// Swap two leaves' positions
    func swapping(_ id1: UUID, _ id2: UUID) -> SplitNode {
        switch self {
        case .leaf(let id):
            if id == id1 { return .leaf(id: id2) }
            if id == id2 { return .leaf(id: id1) }
            return self
        case .split(let id, let axis, let ratio, let a, let b):
            return .split(id: id, axis: axis, ratio: ratio,
                          first: a.swapping(id1, id2),
                          second: b.swapping(id1, id2))
        }
    }

    /// Extract (remove) leaf and return (remaining tree, extracted leaf sentinel)
    func extracting(leaf targetID: UUID) -> (remaining: SplitNode?, extracted: SplitNode?) {
        if case .leaf(let id) = self, id == targetID {
            return (nil, self)
        }
        let remaining = removing(leaf: targetID)
        let extracted: SplitNode? = contains(leaf: targetID) ? .leaf(id: targetID) : nil
        return (remaining, extracted)
    }
}
