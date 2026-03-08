//
//  ContentView.swift
//  MetadataRemover
//
//  Created by Daniel Santos Mendez on 07/03/26.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ContentView: View {
    
    @StateObject private var viewModel = MetadataEditorViewModel()
    @State private var showDocumentPicker = false
    @State private var showPhotoPicker = false
    @State private var showInfoSheet = false
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.selectedFileURL == nil {
                    EmptyStateView(
                        onSelectFile: { showDocumentPicker = true },
                        onSelectPhoto: { showPhotoPicker = true }
                    )
                } else {
                    MetadataEditorView(viewModel: viewModel)
                }
            }
            .navigationTitle("Metadata Remover")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.selectedFileURL != nil {
                        Button("Close") {
                            viewModel.clear()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showInfoSheet = true }) {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { url in
                Task {
                    await viewModel.loadFile(from: url, source: .files)
                }
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker { url in
                Task {
                    await viewModel.loadFile(from: url, source: .photosLibrary)
                }
            }
        }
        .sheet(isPresented: $showInfoSheet) {
            InfoView()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .alert("Success", isPresented: $viewModel.showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.successMessage ?? "Operation completed successfully")
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let onSelectFile: () -> Void
    let onSelectPhoto: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
            
            // Title
            Text("Metadata Remover")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Subtitle
            Text("Protect your privacy by removing metadata from photos and videos")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                Button(action: onSelectPhoto) {
                    Label("Select from Photos", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button(action: onSelectFile) {
                    Label("Browse Files", systemImage: "folder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.2))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 32)
            
            // Privacy note
            Label("Your files never leave your device", systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 16)
            
            Spacer()
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let onSelect: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [
            .image,
            .movie,
            .video,
            .jpeg,
            .png,
            .tiff,
            .gif,
            UTType(filenameExtension: "heic")!,
            UTType(filenameExtension: "mov")!,
            UTType(filenameExtension: "mp4")!,
            UTType(filenameExtension: "avi")!,
            UTType(filenameExtension: "mkv")!
        ]
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onSelect: (URL) -> Void
        
        init(onSelect: @escaping (URL) -> Void) {
            self.onSelect = onSelect
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onSelect(url)
        }
    }
}

// MARK: - Photo Picker

struct PhotoPicker: UIViewControllerRepresentable {
    let onSelect: (URL) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .any(of: [.images, .videos])
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelect: (URL) -> Void
        
        init(onSelect: @escaping (URL) -> Void) {
            self.onSelect = onSelect
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else { return }
            
            // Use NSItemProvider to load the file representation
            let itemProvider = result.itemProvider
            
            // Determine the type identifier
            let typeIdentifier: String
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                typeIdentifier = UTType.image.identifier
            } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                typeIdentifier = UTType.movie.identifier
            } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                typeIdentifier = UTType.data.identifier
            } else {
                return
            }
            
            // Load the file representation
            itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                guard let url = url else {
                    print("Error loading file: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // Copy to a temporary location since the provided URL is temporary
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension)
                
                do {
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    DispatchQueue.main.async {
                        self.onSelect(tempURL)
                    }
                } catch {
                    print("Error copying file: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Info View

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("About") {
                    Text("Metadata Remover helps you protect your privacy by removing sensitive information embedded in your photos and videos.")
                }
                
                Section("What is Metadata?") {
                    Text("Metadata is hidden information stored in files, including:")
                        .padding(.bottom, 4)
                    
                    Label("GPS location coordinates", systemImage: "location.fill")
                    Label("Camera make and model", systemImage: "camera.fill")
                    Label("Date and time taken", systemImage: "calendar")
                    Label("Software used", systemImage: "laptopcomputer")
                }
                
                Section("Features") {
                    Label("View all metadata in text format", systemImage: "doc.text")
                    Label("Edit metadata values", systemImage: "pencil")
                    Label("Apply changes immediately", systemImage: "bolt.fill")
                    Label("Save back to Photos", systemImage: "photo.on.rectangle")
                }
                
                Section("Privacy") {
                    Text("All processing happens locally on your device. Your files are never uploaded to any server.")
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
