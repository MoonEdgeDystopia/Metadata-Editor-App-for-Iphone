//
//  ImageMetadataService.swift
//  MetadataRemover
//
//  Created by Daniel Santos Mendez on 07/03/26.
//

import Foundation
import ImageIO
import MobileCoreServices
import UniformTypeIdentifiers

/// Service for reading and manipulating image metadata (EXIF, IPTC, GPS, etc.)
actor ImageMetadataService {
    
    // MARK: - Reading Metadata
    
    /// Reads all metadata from an image file
    func readMetadata(from url: URL) async throws -> [MetadataItem] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw MetadataError.failedToReadMetadata
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            throw MetadataError.noMetadataFound
        }
        
        var metadataItems: [MetadataItem] = []
        
        // Process all property groups
        for (key, value) in properties {
            let items = processProperty(key: key, value: value, prefix: "")
            metadataItems.append(contentsOf: items)
        }
        
        return metadataItems.sorted { $0.category.rawValue < $1.category.rawValue }
    }
    
    /// Recursively processes metadata properties
    private func processProperty(key: String, value: Any, prefix: String) -> [MetadataItem] {
        var items: [MetadataItem] = []
        let fullKey = prefix.isEmpty ? key : "\(prefix).\(key)"
        
        if let dict = value as? [String: Any] {
            // Nested dictionary - recurse
            for (subKey, subValue) in dict {
                let subItems = processProperty(key: subKey, value: subValue, prefix: fullKey)
                items.append(contentsOf: subItems)
            }
        } else if let array = value as? [Any] {
            // Array value
            for (index, element) in array.enumerated() {
                let arrayKey = "\(fullKey)[\(index)]"
                let subItems = processProperty(key: arrayKey, value: element, prefix: "")
                items.append(contentsOf: subItems)
            }
        } else {
            // Leaf value
            let category = categorizeMetadata(key: fullKey)
            let displayName = displayNameForKey(fullKey)
            
            let item = MetadataItem(
                key: fullKey,
                displayName: displayName,
                originalValue: value,
                category: category,
                isSelected: false,
                isEditable: isEditableKey(fullKey)
            )
            items.append(item)
        }
        
        return items
    }
    
    /// Determines the category for a metadata key
    private func categorizeMetadata(key: String) -> MetadataCategory {
        let lowerKey = key.lowercased()
        
        if lowerKey.contains("gps") || lowerKey.contains("location") {
            return .location
        }
        if lowerKey.contains("exif") || lowerKey.contains("fnumber") || 
           lowerKey.contains("iso") || lowerKey.contains("exposure") ||
           lowerKey.contains("focal") || lowerKey.contains("flash") ||
           lowerKey.contains("metering") || lowerKey.contains("whitebalance") {
            return .camera
        }
        if lowerKey.contains("datetime") || lowerKey.contains("date") ||
           lowerKey.contains("subsec") || lowerKey.contains("timestamp") {
            return .date
        }
        if lowerKey.contains("artist") || lowerKey.contains("author") ||
           lowerKey.contains("creator") || lowerKey.contains("owner") {
            return .author
        }
        if lowerKey.contains("copyright") {
            return .copyright
        }
        if lowerKey.contains("software") || lowerKey.contains("hostcomputer") {
            return .software
        }
        if lowerKey.contains("description") || lowerKey.contains("comment") ||
           lowerKey.contains("subject") || lowerKey.contains("title") ||
           lowerKey.contains("keyword") {
            return .description
        }
        if lowerKey.contains("pixel") || lowerKey.contains("resolution") ||
           lowerKey.contains("colorspace") || lowerKey.contains("bits") ||
           lowerKey.contains("compression") || lowerKey.contains("orientation") {
            return .technical
        }
        
        return .other
    }
    
    /// Returns a human-readable display name for a metadata key
    private func displayNameForKey(_ key: String) -> String {
        // Remove common prefixes
        var cleanKey = key
            .replacingOccurrences(of: "{Exif}", with: "")
            .replacingOccurrences(of: "{GPS}", with: "")
            .replacingOccurrences(of: "{IPTC}", with: "")
            .replacingOccurrences(of: "{JFIF}", with: "")
            .replacingOccurrences(of: "{TIFF}", with: "")
        
        // Remove leading dot if present
        if cleanKey.hasPrefix(".") {
            cleanKey = String(cleanKey.dropFirst())
        }
        
        // Convert camelCase to spaced words
        let spaced = cleanKey.replacingOccurrences(
            of: "([A-Z])",
            with: " $1",
            options: .regularExpression
        )
        
        return spaced.trimmingCharacters(in: .whitespaces)
    }
    
    /// Determines if a metadata key is editable
    private func isEditableKey(_ key: String) -> Bool {
        // Most metadata is editable, except some technical properties
        let nonEditableKeys = [
            "PixelXDimension", "PixelYDimension",
            "BitsPerSample", "SamplesPerPixel"
        ]
        
        return !nonEditableKeys.contains { key.contains($0) }
    }
    
    // MARK: - Writing Metadata
    
    /// Removes selected metadata from an image
    func removeMetadata(
        from sourceURL: URL,
        keysToRemove: [String],
        outputURL: URL? = nil
    ) async throws -> URL {
        // Read the original image data
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw MetadataError.failedToReadMetadata
        }
        
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw MetadataError.invalidData
        }
        
        // Get original properties
        let originalProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        
        // Create filtered properties
        var filteredProperties = originalProperties
        removeKeys(keysToRemove, from: &filteredProperties)
        
        // Determine output URL
        let destinationURL = outputURL ?? createTemporaryOutputURL(for: sourceURL)
        
        // Get the UTI type
        guard let type = CGImageSourceGetType(source) else {
            throw MetadataError.unsupportedFileType
        }
        
        // Create destination with filtered metadata
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            type,
            1,
            nil
        ) else {
            throw MetadataError.failedToWriteMetadata
        }
        
        // Add image with filtered properties
        CGImageDestinationAddImage(destination, image, filteredProperties as CFDictionary)
        
        // Finalize
        if !CGImageDestinationFinalize(destination) {
            throw MetadataError.failedToSaveFile
        }
        
        return destinationURL
    }
    
    /// Recursively removes keys from a nested dictionary
    private func removeKeys(_ keys: [String], from dictionary: inout [String: Any]) {
        for key in keys {
            removeKey(key, from: &dictionary)
        }
    }
    
    private func removeKey(_ key: String, from dictionary: inout [String: Any]) {
        // Handle nested keys with dot notation (e.g., "{Exif}.DateTime")
        if key.contains(".") {
            let components = key.split(separator: ".", maxSplits: 1)
            let firstKey = String(components[0])
            let restKey = components.count > 1 ? String(components[1]) : ""
            
            if var subDict = dictionary[firstKey] as? [String: Any] {
                removeKey(restKey, from: &subDict)
                dictionary[firstKey] = subDict
            }
        } else {
            dictionary.removeValue(forKey: key)
        }
        
        // Also try to match partial keys
        for (dictKey, _) in dictionary {
            if dictKey.contains(key) || key.contains(dictKey) {
                dictionary.removeValue(forKey: dictKey)
            }
        }
    }
    
    /// Applies a privacy preset to an image
    func applyPrivacyPreset(
        _ preset: PrivacyPreset,
        to sourceURL: URL,
        outputURL: URL? = nil
    ) async throws -> URL {
        let keysToRemove = await MainActor.run { preset.keysToRemove() }
        return try await removeMetadata(
            from: sourceURL,
            keysToRemove: keysToRemove,
            outputURL: outputURL
        )
    }
    
    /// Updates specific metadata values
    func updateMetadata(
        from sourceURL: URL,
        updates: [String: Any],
        outputURL: URL? = nil
    ) async throws -> URL {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw MetadataError.failedToReadMetadata
        }
        
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw MetadataError.invalidData
        }
        
        var properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        
        // Apply updates
        for (key, value) in updates {
            setValue(value, forKey: key, in: &properties)
        }
        
        let destinationURL = outputURL ?? createTemporaryOutputURL(for: sourceURL)
        
        guard let type = CGImageSourceGetType(source) else {
            throw MetadataError.unsupportedFileType
        }
        
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            type,
            1,
            nil
        ) else {
            throw MetadataError.failedToWriteMetadata
        }
        
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        
        if !CGImageDestinationFinalize(destination) {
            throw MetadataError.failedToSaveFile
        }
        
        return destinationURL
    }
    
    private func setValue(_ value: Any, forKey key: String, in dictionary: inout [String: Any]) {
        if key.contains(".") {
            let components = key.split(separator: ".", maxSplits: 1)
            let firstKey = String(components[0])
            let restKey = components.count > 1 ? String(components[1]) : ""
            
            var subDict = dictionary[firstKey] as? [String: Any] ?? [:]
            setValue(value, forKey: restKey, in: &subDict)
            dictionary[firstKey] = subDict
        } else {
            dictionary[key] = value
        }
    }
    
    // MARK: - Helper Methods
    
    /// Creates a temporary output URL for processed files
    private func createTemporaryOutputURL(for sourceURL: URL) -> URL {
        let filename = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension
        let timestamp = Int(Date().timeIntervalSince1970)
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("\(filename)_cleaned_\(timestamp).\(ext)")
    }
    
    /// Checks if a file type is supported
    func isSupported(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let supportedExtensions = ["jpg", "jpeg", "png", "heic", "tiff", "tif", "bmp", "gif"]
        return supportedExtensions.contains(ext)
    }
    
    /// Gets a preview image from the file
    func getPreviewImage(from url: URL) async throws -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        let options: [NSString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 1024,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}

// Import UIKit for UIImage
import UIKit
