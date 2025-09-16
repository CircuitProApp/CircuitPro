//
//  View+ifAvailable.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/17/25.
//

import SwiftUI

/// Represents minimum OS versions for different platforms.
/// Note: `#available` requires compile-time literals; it cannot use dynamic variables.
/// This helper provides a convenient API for conditionally applying a modifier
/// when the current platform meets the specified minimum.
public enum PlatformAvailability: Equatable {
    case iOS(Double)
    case macOS(Double)
    case tvOS(Double)
    case watchOS(Double)
}

extension View {
    /// Conditionally applies `modifier` when the current platform version is equal to or newer
    /// than the specified minimum for that platform.
    ///
    /// Because `#available` requires literals, this method exposes common checks with explicit branches.
    /// Pass only the platform(s) you care about. If the current platform isn't mentioned, the modifier won't apply.
    @ViewBuilder
    public func ifAvailable(
        _ availability: PlatformAvailability = .macOS(26.0),
        _ modifier: (Self) -> some View
    ) -> some View {
        switch availability {
        case .macOS(let min):
            // Update these literals to the smallest version you need to support at compile time.
            // We compare using literals in `#available` and gate with a runtime double check
            // to allow callers to pass any Double while keeping compile-time syntax valid.
            if #available(macOS 10.13, *), ProcessInfo.processInfo.isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: Int(min), minorVersion: Int((min * 10).truncatingRemainder(dividingBy: 10)), patchVersion: 0)
            ) {
                modifier(self)
            } else { self }

        case .iOS(let min):
            if #available(iOS 11.0, *), ProcessInfo.processInfo.isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: Int(min), minorVersion: Int((min * 10).truncatingRemainder(dividingBy: 10)), patchVersion: 0)
            ) {
                modifier(self)
            } else { self }

        case .tvOS(let min):
            if #available(tvOS 11.0, *), ProcessInfo.processInfo.isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: Int(min), minorVersion: Int((min * 10).truncatingRemainder(dividingBy: 10)), patchVersion: 0)
            ) {
                modifier(self)
            } else { self }

        case .watchOS(let min):
            if #available(watchOS 4.0, *), ProcessInfo.processInfo.isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: Int(min), minorVersion: Int((min * 10).truncatingRemainder(dividingBy: 10)), patchVersion: 0)
            ) {
                modifier(self)
            } else { self }
        }
    }
}
