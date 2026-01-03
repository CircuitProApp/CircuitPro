//
//  CanvasItem.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import Foundation

/// A lightweight, ID-stable item used by render layers and interactions.
protocol CanvasItem: Identifiable where ID == UUID {}
