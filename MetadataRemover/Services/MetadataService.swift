//
//  MetadataService.swift
//  MetadataRemover
//
//  Created by Daniel Santos Mendez on 07/03/26.
//

import Foundation
import UIKit
import Combine

/// Unified service for handling metadata across all file types
@MainActor
class MetadataService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = MetadataService()
    
    // MARK: - Services
    
    private let imageService = ImageMetadataService()
    private let videoService = VideoMetadataService()
    private let photosService = PhotosService.shared
    
    // MARK: - Published Properties
    
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var lastError: Error?
    
    // MARK: - File Type Detection
    
    /// Determines the file type from a URL
    func detectFileType(_ url: URL) -> FileType {
        return FileType.from(url: url)
    }
    
    /// Checks if a file is supported
    func isSupported(_ url: URL) -> Bool {
        let type = detectFileType(url)
        return type != .unknown
    }
    
    // MARK: - Reading Metadata
    
    /// Reads metadata from any supported file
    func readMetadata(from url: URL) async throws -> [MetadataItem] {
        isProcessing = true
        defer { isProcessing = false }
        
        let fileType = detectFileType(url)
        
        switch fileType {
        case .image:
            return try await imageService.readMetadata(from: url)
        case .video:
            return try await videoService.readMetadata(from: url)
        case .livePhoto:
            // Handle live photo as image for now
            return try await imageService.readMetadata(from: url)
        case .unknown:
            throw MetadataError.unsupportedFileType
        }
    }
    
    /// Gets a preview image for any supported file
    func getPreviewImage(from url: URL) async throws -> UIImage? {
        let fileType = detectFileType(url)
        
        switch fileType {
        case .image:
            return try await imageService.getPreviewImage(from: url)
        case .video:
            return try await videoService.getPreviewImage(from: url)
        case .livePhoto:
            return try await imageService.getPreviewImage(from: url)
        case .unknown:
            return nil
        }
    }
    
    // MARK: - Removing Metadata
    
    /// Removes selected metadata keys from a file
    func removeMetadata(
        from sourceURL: URL,
        keysToRemove: [String],
        outputURL: URL? = nil
    ) async throws -> URL {
        isProcessing = true
        defer { isProcessing = false }
        
        let fileType = detectFileType(sourceURL)
        
        switch fileType {
        case .image:
            return try await imageService.removeMetadata(
                from: sourceURL,
                keysToRemove: keysToRemove,
                outputURL: outputURL
            )
        case .video:
            return try await videoService.removeMetadata(
                from: sourceURL,
                keysToRemove: keysToRemove,
                outputURL: outputURL
            )
        case .livePhoto:
            return try await imageService.removeMetadata(
                from: sourceURL,
                keysToRemove: keysToRemove,
                outputURL: outputURL
            )
        case .unknown:
            throw MetadataError.unsupportedFileType
        }
    }
    
    /// Applies a privacy preset to remove specific metadata categories
    func applyPrivacyPreset(
        _ preset: PrivacyPreset,
        to sourceURL: URL,
        outputURL: URL? = nil
    ) async throws -> URL {
        isProcessing = true
        defer { isProcessing = false }
        
        let fileType = detectFileType(sourceURL)
        
        switch fileType {
        case .image:
            return try await imageService.applyPrivacyPreset(
                preset,
                to: sourceURL,
                outputURL: outputURL
            )
        case .video:
            return try await videoService.applyPrivacyPreset(
                preset,
                to: sourceURL,
                outputURL: outputURL
            )
        case .livePhoto:
            return try await imageService.applyPrivacyPreset(
                preset,
                to: sourceURL,
                outputURL: outputURL
            )
        case .unknown:
            throw MetadataError.unsupportedFileType
        }
    }
    
    // MARK: - Updating Metadata
    
    /// Updates specific metadata values
    func updateMetadata(
        from sourceURL: URL,
        updates: [String: Any],
        outputURL: URL? = nil
    ) async throws -> URL {
        isProcessing = true
        defer { isProcessing = false }
        
        let fileType = detectFileType(sourceURL)
        
        switch fileType {
        case .image:
            return try await imageService.updateMetadata(
                from: sourceURL,
                updates: updates,
                outputURL: outputURL
            )
        case .video:
            return try await videoService.updateMetadata(
                from: sourceURL,
                updates: updates,
                outputURL: outputURL
            )
        case .livePhoto:
            return try await imageService.updateMetadata(
                from: sourceURL,
                updates: updates,
                outputURL: outputURL
            )
        case .unknown:
            throw MetadataError.unsupportedFileType
        }
    }
    
    // MARK: - Save to Original Source
    
    /// Saves file back to its original source (Photos or Files)
    func saveToOriginalSource(
        fileURL: URL,
        source: FileSource,
        fileType: FileType
    ) async throws {
        switch source {
        case .photosLibrary:
            try await photosService.saveToPhotos(fileURL, fileType: fileType)
        case .files, .unknown:
            // For files, the user can use the share sheet or we could implement
            // overwriting the original file with proper permissions
            throw MetadataError.permissionDenied
        }
    }
    
    // MARK: - Batch Operations
    
    /// Processes multiple files with the same operation
    func batchRemoveMetadata(
        from urls: [URL],
        keysToRemove: [String]
    ) async -> [(URL, Result<URL, Error>)] {
        var results: [(URL, Result<URL, Error>)] = []
        let total = Double(urls.count)
        
        for (index, url) in urls.enumerated() {
            progress = Double(index) / total
            
            do {
                let outputURL = try await removeMetadata(
                    from: url,
                    keysToRemove: keysToRemove
                )
                results.append((url, .success(outputURL)))
            } catch {
                results.append((url, .failure(error)))
            }
        }
        
        progress = 1.0
        return results
    }
    
    /// Applies a privacy preset to multiple files
    func batchApplyPrivacyPreset(
        _ preset: PrivacyPreset,
        to urls: [URL]
    ) async -> [(URL, Result<URL, Error>)] {
        var results: [(URL, Result<URL, Error>)] = []
        let total = Double(urls.count)
        
        for (index, url) in urls.enumerated() {
            progress = Double(index) / total
            
            do {
                let outputURL = try await applyPrivacyPreset(preset, to: url)
                results.append((url, .success(outputURL)))
            } catch {
                results.append((url, .failure(error)))
            }
        }
        
        progress = 1.0
        return results
    }
    
    // MARK: - Helper Methods
    
    /// Generates a suggested output filename
    func suggestedOutputFilename(for url: URL, suffix: String = "_cleaned") -> String {
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        return "\(baseName)\(suffix).\(ext)"
    }
    
    /// Gets file size in human-readable format
    func getFileSize(_ url: URL) -> String? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? Int64 {
                return formatBytes(size)
            }
        } catch {
            // Return nil if unable to get size
        }
        return nil
    }
    
    /// Formats bytes to human-readable string
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Cleans up temporary files
    func cleanupTemporaryFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: tempDir,
                includingPropertiesForKeys: nil
            )
            for file in files {
                if file.lastPathComponent.contains("_cleaned_") || 
                   file.lastPathComponent.contains("_modified_") {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            // Ignore cleanup errors
        }
    }
}

// MARK: - AVAsset Extension

extension AVAsset {
    func loadValues(forKeys keys: [String]) async {
        await withCheckedContinuation { continuation in
            self.loadValuesAsynchronously(forKeys: keys) {
                continuation.resume()
            }
        }
    }
}

import AVFoundation
import Photos
