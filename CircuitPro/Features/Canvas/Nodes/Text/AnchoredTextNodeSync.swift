//
//  AnchoredTextNodeSync.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import Foundation

enum AnchoredTextNodeSync {
    static func sync(
        parent: BaseNode,
        owner: TextOwningInstance,
        renderableTexts: [RenderableText]
    ) -> Bool {
        guard let ownerID = owner.id as? UUID else { return false }

        let existingTextNodes = parent.children.compactMap { $0 as? AnchoredTextNode }
        let existingByID = Dictionary(uniqueKeysWithValues: existingTextNodes.map { ($0.id, $0) })

        var updatedTextNodes: [AnchoredTextNode] = []
        updatedTextNodes.reserveCapacity(renderableTexts.count)

        var updatedIDs = Set<UUID>()
        var didChange = false

        for renderable in renderableTexts {
            let targetID: UUID
            switch renderable.model.source {
            case .definition(let definition):
                targetID = AnchoredTextNode.stableID(for: ownerID, definitionID: definition.id)
            case .instance:
                targetID = renderable.model.id
            }

            updatedIDs.insert(targetID)

            if let node = existingByID[targetID] {
                if node.resolvedText != renderable.model {
                    node.resolvedText = renderable.model
                    node.invalidateContentBoundingBox()
                    didChange = true
                }
                if node.displayText != renderable.text {
                    node.displayText = renderable.text
                    node.invalidateContentBoundingBox()
                    didChange = true
                }
                updatedTextNodes.append(node)
            } else {
                let node = AnchoredTextNode(
                    resolvedText: renderable.model,
                    text: renderable.text,
                    ownerInstance: owner
                )
                node.parent = parent
                updatedTextNodes.append(node)
                didChange = true
            }
        }

        if existingTextNodes.contains(where: { !updatedIDs.contains($0.id) }) {
            didChange = true
        }

        guard didChange else { return false }

        let coreChildren = parent.children.filter { !($0 is AnchoredTextNode) }
        parent.children = coreChildren + updatedTextNodes
        for child in parent.children {
            child.parent = parent
        }

        return true
    }
}
