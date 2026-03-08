//
//  MetadataEditorViewModel.swift
//  MetadataRemover
//
//  Created by Daniel Santos Mendez on 07/03/26.
//

import Foundation
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Combine

/// ViewModel for managing metadata editing operations
@MainActor
class MetadataEditorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var selectedFileURL: URL?
    @Published var originalFileURL: URL?
    @Published var fileSource: FileSource = .unknown
    @Published var fileType: FileType = .unknown
    @Published var fileSize: String?
    @Published var previewImage: UIImage?
    
    @Published var metadataItems: [MetadataItem] = []
    @Published var filteredMetadataItems: [MetadataItem] = []
    @Published var selectedCategory: MetadataCategory?
    
    @Published var isLoading = false
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0
    
    @Published var errorMessage: String?
    @Published var showError = false
    
    @Published var showSuccess = false
    @Published var successMessage: String?
    
    @Published var searchQuery: String = "" {
        didSet {
            filterMetadata()
        }
    }
    
    @Published var selectedItems: Set<UUID> = []
    @Published var hasChanges = false
    
    @Published var showPrivacyPresets = false
    @Published var showExportSheet = false
    @Published var showMetadataText = false
    @Published var showEditSheet = false
    @Published var editingItem: MetadataItem?
    @Published var processedFileURL: URL?
    
    @Published var metadataText: String = ""
    
    // MARK: - Services
    
    private let metadataService = MetadataService.shared
    private let photosService = PhotosService.shared
    
    // MARK: - Computed Properties
    
    var hasMetadata: Bool {
        !metadataItems.isEmpty
    }
    
    var selectedCount: Int {
        metadataItems.filter { $0.isSelected }.count
    }
    
    var modifiedCount: Int {
        metadataItems.filter { $0.hasChanges }.count
    }
    
    var metadataByCategory: [MetadataCategory: [MetadataItem]] {
        Dictionary(grouping: filteredMetadataItems) { $0.category }
    }
    
    var categories: [MetadataCategory] {
        Array(metadataByCategory.keys).sorted { $0.rawValue < $1.rawValue }
    }
    
    // MARK: - File Selection
    
    /// Loads a file from a URL (document picker or other sources)
    func loadFile(from url: URL, source: FileSource = .files) async {
        isLoading = true
        defer { isLoading = false }
        
        // Security-scoped resource handling
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Validate file type
        guard metadataService.isSupported(url) else {
            showError("This file type is not supported. Please select an image or video file.")
            return
        }
        
        selectedFileURL = url
        originalFileURL = url
        fileSource = source
        fileType = metadataService.detectFileType(url)
        fileSize = metadataService.getFileSize(url)
        
        // Load preview
        do {
            previewImage = try await metadataService.getPreviewImage(from: url)
        } catch {
            // Preview is optional, continue without it
            previewImage = nil
        }
        
        // Load metadata
        do {
            metadataItems = try await metadataService.readMetadata(from: url)
            filteredMetadataItems = metadataItems
            updateMetadataText()
            hasChanges = false
        } catch {
            showError("Failed to read metadata: \(error.localizedDescription)")
            metadataItems = []
            filteredMetadataItems = []
        }
    }
    
    // MARK: - Metadata Operations
    
    /// Toggles selection of a metadata item
    func toggleSelection(for item: MetadataItem) {
        if let index = metadataItems.firstIndex(where: { $0.id == item.id }) {
            metadataItems[index].isSelected.toggle()
            hasChanges = metadataItems.contains { $0.isSelected }
            filterMetadata()
        }
    }
    
    /// Selects all items in a category
    func selectAll(in category: MetadataCategory) {
        for index in metadataItems.indices {
            if metadataItems[index].category == category && metadataItems[index].isEditable {
                metadataItems[index].isSelected = true
            }
        }
        hasChanges = metadataItems.contains { $0.isSelected }
        filterMetadata()
    }
    
    /// Deselects all items in a category
    func deselectAll(in category: MetadataCategory) {
        for index in metadataItems.indices {
            if metadataItems[index].category == category {
                metadataItems[index].isSelected = false
            }
        }
        hasChanges = metadataItems.contains { $0.isSelected }
        filterMetadata()
    }
    
    /// Selects all metadata items
    func selectAllItems() {
        for index in metadataItems.indices {
            if metadataItems[index].isEditable {
                metadataItems[index].isSelected = true
            }
        }
        hasChanges = true
        filterMetadata()
    }
    
    /// Deselects all metadata items
    func deselectAllItems() {
        for index in metadataItems.indices {
            metadataItems[index].isSelected = false
        }
        hasChanges = false
        filterMetadata()
    }
    
    /// Applies the current selected changes immediately
    func applyCurrentChanges() async {
        guard let sourceURL = selectedFileURL else { return }
        
        let keysToRemove = metadataItems
            .filter { $0.isSelected }
            .map { $0.key }
        
        guard !keysToRemove.isEmpty else {
            // No keys selected, revert to original if needed
            if let original = originalFileURL, selectedFileURL != original {
                selectedFileURL = original
                // Reload metadata from original
                await loadFile(from: original, source: fileSource)
            }
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let outputURL = try await metadataService.removeMetadata(
                from: sourceURL,
                keysToRemove: keysToRemove
            )
            
            selectedFileURL = outputURL
            processedFileURL = outputURL
            
            // Reload metadata from the new file
            let newMetadata = try await metadataService.readMetadata(from: outputURL)
            
            // Preserve selection state for items that still exist
            metadataItems = newMetadata.map { newItem in
                var item = newItem
                if let oldItem = metadataItems.first(where: { $0.key == newItem.key }) {
                    item.isSelected = oldItem.isSelected
                }
                return item
            }
            
            filteredMetadataItems = metadataItems
            updateMetadataText()
            
            hasChanges = selectedCount > 0
        } catch {
            showError("Failed to apply changes: \(error.localizedDescription)")
        }
    }
    
    /// Edits a metadata value
    func editMetadataValue(for item: MetadataItem, newValue: Any) async {
        guard let sourceURL = selectedFileURL else {
            showError("No file selected")
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // Update the edited value
            if let index = metadataItems.firstIndex(where: { $0.id == item.id }) {
                metadataItems[index].editedValue = newValue
            }
            
            let outputURL = try await metadataService.updateMetadata(
                from: sourceURL,
                updates: [item.key: newValue]
            )
            
            selectedFileURL = outputURL
            processedFileURL = outputURL
            
            // Reload metadata
            await loadFile(from: outputURL, source: fileSource)
            
            showSuccess("Updated metadata value successfully!")
        } catch {
            showError("Failed to update value: \(error.localizedDescription)")
        }
    }
    
    /// Applies a privacy preset
    func applyPrivacyPreset(_ preset: PrivacyPreset) async {
        guard let sourceURL = selectedFileURL else {
            showError("No file selected")
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let outputURL = try await metadataService.applyPrivacyPreset(preset, to: sourceURL)
            
            selectedFileURL = outputURL
            processedFileURL = outputURL
            
            // Reload metadata from the new file
            await loadFile(from: outputURL, source: fileSource)
            
            showSuccess("Applied \(preset.rawValue) preset successfully!")
            hasChanges = false
        } catch {
            showError("Failed to apply preset: \(error.localizedDescription)")
        }
    }
    
    /// Removes selected metadata
    func removeSelectedMetadata() async -> URL? {
        guard let sourceURL = selectedFileURL else {
            showError("No file selected")
            return nil
        }
        
        let keysToRemove = metadataItems
            .filter { $0.isSelected }
            .map { $0.key }
        
        guard !keysToRemove.isEmpty else {
            showError("No metadata selected for removal")
            return nil
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let outputURL = try await metadataService.removeMetadata(
                from: sourceURL,
                keysToRemove: keysToRemove
            )
            
            processedFileURL = outputURL
            selectedFileURL = outputURL
            
            // Reload metadata from the new file
            await loadFile(from: outputURL, source: fileSource)
            
            showSuccess("Removed \(keysToRemove.count) metadata items successfully!")
            hasChanges = false
            
            return outputURL
        } catch {
            showError("Failed to remove metadata: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Save to Original Source
    
    /// Saves the modified file back to the original source
    func saveToOriginalSource() async {
        guard let fileURL = processedFileURL ?? selectedFileURL else {
            showError("No file to save")
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            if fileSource == .photosLibrary {
                // Save to Photos library
                try await photosService.saveToPhotos(fileURL, fileType: fileType)
                showSuccess("Saved to Photos library successfully!")
            } else {
                // For files, use share sheet or document picker
                showExportSheet = true
            }
        } catch {
            showError("Failed to save: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Metadata Text Export
    
    /// Generates metadata text representation
    func updateMetadataText() {
        var text = "METADATA REPORT\n"
        text += "================\n\n"
        
        if let url = selectedFileURL {
            text += "File: \(url.lastPathComponent)\n"
            text += "Type: \(fileType.rawValue)\n"
            if let size = fileSize {
                text += "Size: \(size)\n"
            }
            text += "\n"
        }
        
        text += "METADATA ITEMS (\(metadataItems.count) total)\n"
        text += "----------------\n\n"
        
        for category in categories {
            text += "\(category.rawValue.uppercased())\n"
            text += String(repeating: "-", count: category.rawValue.count) + "\n"
            
            let items = metadataItems.filter { $0.category == category }
            for item in items {
                let status = item.isSelected ? "[REMOVE]" : (item.hasChanges ? "[MODIFIED]" : "[KEEP]")
                text += "\(item.displayName): \(item.displayValue) \(status)\n"
            }
            text += "\n"
        }
        
        text += "\nSUMMARY\n"
        text += "-------\n"
        text += "Total items: \(metadataItems.count)\n"
        text += "Selected for removal: \(selectedCount)\n"
        text += "Modified: \(modifiedCount)\n"
        
        metadataText = text
    }
    
    /// Exports metadata text to a file
    func exportMetadataText() -> URL? {
        let filename = "metadata_\(selectedFileURL?.deletingPathExtension().lastPathComponent ?? "report").txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try metadataText.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            showError("Failed to export metadata text: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Filtering
    
    /// Filters metadata based on search query and selected category
    private func filterMetadata() {
        var filtered = metadataItems
        
        // Apply category filter
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Apply search filter
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            filtered = filtered.filter { item in
                item.displayName.lowercased().contains(query) ||
                item.displayValue.lowercased().contains(query) ||
                item.key.lowercased().contains(query)
            }
        }
        
        filteredMetadataItems = filtered
    }
    
    /// Sets the category filter
    func filterByCategory(_ category: MetadataCategory?) {
        selectedCategory = category
        filterMetadata()
    }
    
    // MARK: - Export
    
    /// Returns the URL of the processed file for sharing/saving
    func getExportURL() -> URL? {
        return processedFileURL ?? selectedFileURL
    }
    
    /// Clears the current selection and resets the state
    func clear() {
        selectedFileURL = nil
        originalFileURL = nil
        fileSource = .unknown
        fileType = .unknown
        fileSize = nil
        previewImage = nil
        metadataItems = []
        filteredMetadataItems = []
        selectedCategory = nil
        searchQuery = ""
        selectedItems = []
        hasChanges = false
        processedFileURL = nil
        errorMessage = nil
        successMessage = nil
        metadataText = ""
    }
    
    // MARK: - Error Handling
    
    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    private func showSuccess(_ message: String) {
        successMessage = message
        showSuccess = true
    }
}

// MARK: - Import UIKit
import UIKit
