import AppKit

struct FootprintView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    let component: ComponentInstance
    @CKState private var dragStartPosition: CGPoint?
    @CKState private var dragStartPointer: CGPoint?

    var showHalo: Bool {
        context.highlightedItemIDs.contains(component.id) ||
            context.selectedItemIDs.contains(component.id)
    }

    var bodyColor: CKColor {
        CKColor(environment.canvasTheme.textColor)
    }

    var body: some CKView {
        let footprint = component.footprintInstance
        CKGroup {
            if let footprint, let definition = footprint.definition {
                let primitives = resolvedPrimitives(
                    definition.primitives,
                    placement: footprint.placement
                )
                let placementSide = placementSide(for: footprint.placement)
                CKGroup {
                    for primitive in primitives {
                        PrimitiveView(primitive: primitive, isEditable: false)
                    }
                    for pad in definition.pads {
                        PadView(pad: pad, placementSide: placementSide)
                    }
                }
                .halo(showHalo ? bodyColor.haloOpacity() : .clear, width: 5)
                .hoverable(component.id)
                .selectable(component.id)
                .onDragGesture { phase in
                    switch phase {
                    case .began:
                        dragStartPosition = footprint.position
                        dragStartPointer = environment.processedMouseLocation ?? context.mouseLocation
                    case .changed(let delta):
                        guard let startPosition = dragStartPosition,
                              let startPointer = dragStartPointer
                        else { return }
                        let pointer = delta.processedLocation
                        let dx = pointer.x - startPointer.x
                        let dy = pointer.y - startPointer.y
                        context.update(component) { component in
                            component.footprintInstance?.position = CGPoint(
                                x: startPosition.x + dx,
                                y: startPosition.y + dy
                            )
                        }
                    case .ended:
                        dragStartPosition = nil
                        dragStartPointer = nil
                    }
                }

                for text in footprint.resolvedItems where text.isVisible {
                    AnchoredTextView(
                        text: text,
                        id: CanvasTextID.makeID(
                            for: text.source,
                            ownerID: component.id,
                            fallback: text.id
                        ),
                        isParentHighlighted: showHalo,
                        display: { resolved in
                            component.displayString(for: resolved, target: .footprint)
                        },
                        onUpdate: { updated in
                            context.update(component) { component in
                                guard let footprint = component.footprintInstance else { return }
                                var overrides = footprint.textOverrides
                                var instances = footprint.textInstances
                                updated.apply(toOverrides: &overrides, andInstances: &instances)
                                footprint.textOverrides = overrides
                                footprint.textInstances = instances
                            }
                        }
                    )
                }
            }
        }
        .position(footprint?.position ?? .zero)
        .rotation(footprint?.rotation ?? 0)
    }

    private func placementSide(for placement: PlacementState) -> BoardSide {
        switch placement {
        case .placed(let side):
            return side
        case .unplaced:
            return .front
        }
    }

    private func resolvedPrimitives(
        _ primitives: [AnyCanvasPrimitive],
        placement: PlacementState
    ) -> [AnyCanvasPrimitive] {
        guard case .placed(let side) = placement else { return primitives }

        return primitives.map { primitive in
            var copy = primitive
            guard let genericLayerID = copy.layerId,
                  let genericKind = LayerKind.allCases.first(where: { $0.stableId == genericLayerID })
            else {
                return copy
            }

            let targetLayer = context.layers.compactMap { $0 as? PCBLayer }.first { canvasLayer in
                guard let layerKind = canvasLayer.layerKind else { return false }
                let kindMatches = layerKind == genericKind
                let sideMatches =
                    (side == .front && canvasLayer.layerSide == .front)
                    || (side == .back && canvasLayer.layerSide == .back)
                return kindMatches && sideMatches
            }

            copy.layerId = targetLayer?.id
            return copy
        }
    }
}
