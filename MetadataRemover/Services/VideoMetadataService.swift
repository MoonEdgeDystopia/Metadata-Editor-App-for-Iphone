//
//  VideoMetadataService.swift
//  MetadataRemover
//
//  Created by Daniel Santos Mendez on 07/03/26.
//

import Foundation
import AVFoundation
import Photos

/// Service for reading and manipulating video metadata
actor VideoMetadataService {
    
    // MARK: - Reading Metadata
    
    /// Reads all metadata from a video file
    func readMetadata(from url: URL) async throws -> [MetadataItem] {
        let asset = AVAsset(url: url)
        
        // Load required keys
        let keys = ["commonMetadata", "availableMetadataFormats", "tracks"]
        await asset.loadValues(forKeys: keys)
        
        var metadataItems: [MetadataItem] = []
        
        // Read common metadata
        let commonMetadata = await asset.commonMetadata
        for item in commonMetadata {
            if let metadataItem = await processAVMetadataItem(item) {
                metadataItems.append(metadataItem)
            }
        }
        
        // Read format-specific metadata
        let formats = await asset.availableMetadataFormats
        for format in formats {
            let formatMetadata = await asset.metadata(forFormat: format)
            for item in formatMetadata {
                if let metadataItem = await processAVMetadataItem(item) {
                    metadataItems.append(metadataItem)
                }
            }
        }
        
        // Read track information
        let tracks = await asset.tracks
        for (index, track) in tracks.enumerated() {
            let trackMetadata = await processTrack(track, index: index)
            metadataItems.append(contentsOf: trackMetadata)
        }
        
        // Read creation date
        if let creationDate = try? await asset.load(.creationDate) {
            let item = MetadataItem(
                key: "com.apple.quicktime.creationdate",
                displayName: "Creation Date",
                originalValue: creationDate.dateValue,
                category: .date,
                isSelected: false,
                isEditable: false
            )
            metadataItems.append(item)
        }
        
        // Read duration
        let duration = try? await asset.load(.duration)
        let durationItem = MetadataItem(
            key: "duration",
            displayName: "Duration",
            originalValue: formatDuration(duration ?? .zero),
            category: .technical,
            isSelected: false,
            isEditable: false
        )
        metadataItems.append(durationItem)
        
        // Read preferred transform
        if let preferredTransform = try? await asset.load(.preferredTransform) {
            let transformItem = MetadataItem(
                key: "preferredTransform",
                displayName: "Transform",
                originalValue: "\(preferredTransform.a), \(preferredTransform.b), \(preferredTransform.c), \(preferredTransform.d)",
                category: .technical,
                isSelected: false,
                isEditable: false
            )
            metadataItems.append(transformItem)
        }
        
        return metadataItems.sorted { $0.category.rawValue < $1.category.rawValue }
    }
    
    /// Processes an AVMetadataItem into our MetadataItem format
    private func processAVMetadataItem(_ item: AVMetadataItem) async -> MetadataItem? {
        guard let key = item.commonKey?.rawValue ?? item.key as? String else {
            return nil
        }
        
        do {
            let value = try await item.load(.value)
            let category = categorizeVideoMetadata(key: key)
            let displayName = item.commonKey?.rawValue ?? key
            
            return MetadataItem(
                key: key,
                displayName: displayName,
                originalValue: value,
                category: category,
                isSelected: false,
                isEditable: true
            )
        } catch {
            return nil
        }
    }
    
    /// Processes track information
    private func processTrack(_ track: AVAssetTrack, index: Int) async -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        let trackPrefix = "Track \(index + 1)"
        
        // Media type is directly accessible
        items.append(MetadataItem(
            key: "\(trackPrefix).mediaType",
            displayName: "\(trackPrefix) Type",
            originalValue: track.mediaType.rawValue,
            category: .technical,
            isSelected: false,
            isEditable: false
        ))
        
        do {
            let naturalSize = try await track.load(.naturalSize)
            let estimatedDataRate = try? await track.load(.estimatedDataRate)
            let totalSampleDataLength = try? await track.load(.totalSampleDataLength)
            
            items.append(MetadataItem(
                key: "\(trackPrefix).naturalSize",
                displayName: "\(trackPrefix) Resolution",
                originalValue: "\(Int(naturalSize.width))x\(Int(naturalSize.height))",
                category: .technical,
                isSelected: false,
                isEditable: false
            ))
            
            if let dataRate = estimatedDataRate {
                items.append(MetadataItem(
                    key: "\(trackPrefix).estimatedDataRate",
                    displayName: "\(trackPrefix) Data Rate",
                    originalValue: "\(dataRate / 1000) kbps",
                    category: .technical,
                    isSelected: false,
                    isEditable: false
                ))
            }
            
            if let sampleLength = totalSampleDataLength {
                items.append(MetadataItem(
                    key: "\(trackPrefix).totalSampleDataLength",
                    displayName: "\(trackPrefix) Size",
                    originalValue: formatBytes(Int64(sampleLength)),
                    category: .technical,
                    isSelected: false,
                    isEditable: false
                ))
            }
        } catch {
            // Skip track if loading fails
        }
        
        return items
    }
    
    /// Categorizes video metadata keys
    private func categorizeVideoMetadata(key: String) -> MetadataCategory {
        let lowerKey = key.lowercased()
        
        if lowerKey.contains("location") || lowerKey.contains("gps") {
            return .location
        }
        if lowerKey.contains("make") || lowerKey.contains("model") ||
           lowerKey.contains("lens") || lowerKey.contains("camera") {
            return .camera
        }
        if lowerKey.contains("date") || lowerKey.contains("creation") {
            return .date
        }
        if lowerKey.contains("artist") || lowerKey.contains("author") ||
           lowerKey.contains("creator") {
            return .author
        }
        if lowerKey.contains("copyright") {
            return .copyright
        }
        if lowerKey.contains("software") {
            return .software
        }
        if lowerKey.contains("title") || lowerKey.contains("description") ||
           lowerKey.contains("comment") || lowerKey.contains("subject") {
            return .description
        }
        
        return .other
    }
    
    // MARK: - Writing Metadata
    
    /// Removes selected metadata from a video
    func removeMetadata(
        from sourceURL: URL,
        keysToRemove: [String],
        outputURL: URL? = nil
    ) async throws -> URL {
        let asset = AVAsset(url: sourceURL)
        
        // Create composition
        guard let composition = try? await createComposition(from: asset) else {
            throw MetadataError.failedToReadMetadata
        }
        
        // Get original metadata and filter out keys to remove
        let originalMetadata = await asset.commonMetadata
        let filteredMetadata = originalMetadata.filter { item in
            guard let key = item.commonKey?.rawValue ?? item.key as? String else {
                return true
            }
            return !keysToRemove.contains { key.contains($0) || $0.contains(key) }
        }
        
        // Apply filtered metadata to composition
        // Note: AVComposition doesn't directly support metadata modification
        // We'll need to export with custom metadata
        
        let destinationURL = outputURL ?? createTemporaryOutputURL(for: sourceURL)
        
        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw MetadataError.failedToWriteMetadata
        }
        
        exportSession.outputURL = destinationURL
        exportSession.outputFileType = determineOutputFileType(for: sourceURL)
        exportSession.metadata = filteredMetadata
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw MetadataError.failedToSaveFile
        }
        
        return destinationURL
    }
    
    /// Creates a composition from an asset
    private func createComposition(from asset: AVAsset) async throws -> AVMutableComposition {
        let composition = AVMutableComposition()
        
        let tracks = await asset.tracks
        for track in tracks {
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: track.mediaType,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                continue
            }
            
            let timeRange = try await track.load(.timeRange)
            try compositionTrack.insertTimeRange(timeRange, of: track, at: .zero)
        }
        
        return composition
    }
    
    /// Applies a privacy preset to a video
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
        let asset = AVAsset(url: sourceURL)
        
        guard let composition = try? await createComposition(from: asset) else {
            throw MetadataError.failedToReadMetadata
        }
        
        let destinationURL = outputURL ?? createTemporaryOutputURL(for: sourceURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw MetadataError.failedToWriteMetadata
        }
        
        exportSession.outputURL = destinationURL
        exportSession.outputFileType = determineOutputFileType(for: sourceURL)
        
        // Convert updates to AVMetadataItems
        var newMetadata: [AVMetadataItem] = []
        for (key, value) in updates {
            let item = AVMutableMetadataItem()
            item.key = key as NSString
            item.keySpace = .common
            item.value = value as? NSCopying & NSObjectProtocol
            newMetadata.append(item)
        }
        
        exportSession.metadata = newMetadata
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw MetadataError.failedToSaveFile
        }
        
        return destinationURL
    }
    
    // MARK: - Helper Methods
    
    /// Determines the output file type based on source extension
    private func determineOutputFileType(for url: URL) -> AVFileType? {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp4", "m4v":
            return .mp4
        case "mov":
            return .mov
        case "avi":
            // AVI is not directly supported for export in AVFoundation
            return .mp4
        case "mkv":
            // MKV is not directly supported for export
            return .mp4
        default:
            return .mp4
        }
    }
    
    /// Creates a temporary output URL
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
        let supportedExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "wmv", "flv", "webm"]
        return supportedExtensions.contains(ext)
    }
    
    /// Gets a preview image from the video
    func getPreviewImage(from url: URL) async throws -> UIImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 0, preferredTimescale: 1)
        
        do {
            let cgImage = try await generator.image(at: time).image
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
    
    /// Formats duration to readable string
    private func formatDuration(_ duration: CMTime) -> String {
        let totalSeconds = Int(duration.seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    /// Formats bytes to readable string
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// Import UIKit for UIImage
import UIKit
