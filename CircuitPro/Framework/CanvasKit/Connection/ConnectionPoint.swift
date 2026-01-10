//
//  ConnectionPoint.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import CoreGraphics
import Foundation

/// A point on a canvas item that can participate in connections.
///
/// In PCB design, this is typically a pin on a symbol or footprint.
/// In flowcharts, this could be an invisible anchor at an edge midpoint.
/// The protocol is domain-agnostic — CanvasKit uses it to understand
/// where connections can attach.
protocol ConnectionPoint: Identifiable where ID == UUID {
    /// The world-space position of this connection point.
    var position: CGPoint { get }
}
