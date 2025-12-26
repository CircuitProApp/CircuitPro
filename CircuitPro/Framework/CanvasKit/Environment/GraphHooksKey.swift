//
//  GraphHooksKey.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import Foundation

private struct GraphRenderProvidersKey: CanvasEnvironmentKey {
    static let defaultValue: [any GraphRenderProvider] = []
}

private struct GraphHaloProvidersKey: CanvasEnvironmentKey {
    static let defaultValue: [any GraphHaloProvider] = []
}

private struct GraphHitTestProvidersKey: CanvasEnvironmentKey {
    static let defaultValue: [any GraphHitTestProvider] = []
}

extension CanvasEnvironmentValues {
    var graphRenderProviders: [any GraphRenderProvider] {
        get { self[GraphRenderProvidersKey.self] }
        set { self[GraphRenderProvidersKey.self] = newValue }
    }

    var graphHaloProviders: [any GraphHaloProvider] {
        get { self[GraphHaloProvidersKey.self] }
        set { self[GraphHaloProvidersKey.self] = newValue }
    }

    var graphHitTestProviders: [any GraphHitTestProvider] {
        get { self[GraphHitTestProvidersKey.self] }
        set { self[GraphHitTestProvidersKey.self] = newValue }
    }

    func withGraphRenderProviders(_ providers: [any GraphRenderProvider]) -> CanvasEnvironmentValues {
        var copy = self
        copy.graphRenderProviders = providers
        return copy
    }

    func withGraphHaloProviders(_ providers: [any GraphHaloProvider]) -> CanvasEnvironmentValues {
        var copy = self
        copy.graphHaloProviders = providers
        return copy
    }

    func withGraphHitTestProviders(_ providers: [any GraphHitTestProvider]) -> CanvasEnvironmentValues {
        var copy = self
        copy.graphHitTestProviders = providers
        return copy
    }
}
