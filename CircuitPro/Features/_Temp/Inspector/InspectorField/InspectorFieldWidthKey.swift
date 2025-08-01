//
//  InspectorFieldWidthKey.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/30/25.
//

import SwiftUI

struct InspectorFieldWidthKey: EnvironmentKey {
  static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
  /// If non‑nil, this will always be used in preference to any explicit width
  var inspectorFieldWidth: CGFloat? {
    get { self[InspectorFieldWidthKey.self] }
    set { self[InspectorFieldWidthKey.self] = newValue }
  }
}
