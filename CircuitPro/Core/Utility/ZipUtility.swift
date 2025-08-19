//
//  ZipUtility.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//

import Foundation
import Compression

// Custom error for our unzipping logic
enum ZipError: Error {
    case failedToUnzip(String)
}

// This extension adds the 'unzipItem' function to FileManager
extension FileManager {
    
    /// Unzips a file at a given source URL to a destination directory.
    /// This implementation is basic and designed for simplicity. For complex archives, a dedicated library like ZipFoundation is recommended.
    /// - Parameters:
    ///   - sourceURL: The URL of the .zip file.
    ///   - destinationURL: The URL of the directory where contents will be extracted.
    func unzipItem(at sourceURL: URL, to destinationURL: URL) throws {
        // Ensure the source file exists
        guard fileExists(atPath: sourceURL.path) else {
            throw ZipError.failedToUnzip("Source ZIP file not found at \(sourceURL.path)")
        }
        
        // Ensure the destination is a directory, and create it if it doesn't exist
        var isDirectory: ObjCBool = false
        if fileExists(atPath: destinationURL.path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                throw ZipError.failedToUnzip("Destination is not a directory at \(destinationURL.path)")
            }
        } else {
            try createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Use the 'ditto' command-line utility, which is a robust and safe way to handle zip files on Apple platforms.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-x",            // Extract
            "-k",            // Extract PKZip archives
            sourceURL.path,  // Source file
            destinationURL.path // Destination directory
        ]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw ZipError.failedToUnzip("Failed to unzip archive. Ditto process failed with status \(process.terminationStatus).")
        }
    }
}
