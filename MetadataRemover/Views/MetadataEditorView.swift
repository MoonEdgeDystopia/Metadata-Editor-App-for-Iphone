//
//  MetadataEditorView.swift
//  MetadataRemover
//
//  Created by Daniel Santos Mendez on 07/03/26.
//

import SwiftUI

struct MetadataEditorView: View {
    
    @ObservedObject var viewModel: MetadataEditorViewModel
    @State private var showPrivacyPresets = false
    @State private var showExportSheet = false
    @State private var showClearConfirmation = false
    @State private var selectedTab = 0
    @State private var showMetadataTextSheet = false
    @State private var showEditValueSheet = false
    @State private var editingItem: MetadataItem?
    @State private var editValue: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // File Preview Section
            FilePreviewSection(viewModel: viewModel)
                .frame(height: 200)
            
            // Changes status bar
            HStack {
                Text(viewModel.selectedCount > 0 ? "\(viewModel.selectedCount) items selected for removal" : "Tap items to select for removal")
                    .font(.subheadline)
                    .foregroundStyle(viewModel.selectedCount > 0 ? .red : .secondary)
                Spacer()
                
                if viewModel.hasChanges {
                    Button("Apply") {
                        Task {
                            await viewModel.applyCurrentChanges()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            // Action buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ActionButton(
                        title: "View Text",
                        icon: "doc.text",
                        color: .blue
                    ) {
                        viewModel.updateMetadataText()
                        showMetadataTextSheet = true
                    }
                    
                    ActionButton(
                        title: "Privacy Presets",
                        icon: "shield.checkered",
                        color: .green
                    ) {
                        showPrivacyPresets = true
                    }
                    
                    if viewModel.fileSource == .photosLibrary {
                        ActionButton(
                            title: "Save to Photos",
                            icon: "photo.on.rectangle",
                            color: .purple
                        ) {
                            Task {
                                await viewModel.saveToOriginalSource()
                            }
                        }
                    }
                    
                    ActionButton(
                        title: "Share",
                        icon: "square.and.arrow.up",
                        color: .orange
                    ) {
                        showExportSheet = true
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            
            // Tab Selection
            Picker("View", selection: $selectedTab) {
                Text("Metadata").tag(0)
                Text("Categories").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content based on tab
            Group {
                if selectedTab == 0 {
                    MetadataListView(
                        viewModel: viewModel,
                        onEdit: { item in
                            editingItem = item
                            editValue = item.displayValue
                            showEditValueSheet = true
                        }
                    )
                } else {
                    CategoryListView(viewModel: viewModel)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showPrivacyPresets = true
                    } label: {
                        Label("Privacy Presets", systemImage: "shield.checkered")
                    }
                    
                    Button {
                        viewModel.selectAllItems()
                    } label: {
                        Label("Select All", systemImage: "checkmark.circle")
                    }
                    
                    Button {
                        viewModel.deselectAllItems()
                    } label: {
                        Label("Deselect All", systemImage: "xmark.circle")
                    }
                    
                    Button {
                        viewModel.updateMetadataText()
                        showMetadataTextSheet = true
                    } label: {
                        Label("View as Text", systemImage: "doc.text")
                    }
                    
                    if viewModel.fileSource == .photosLibrary {
                        Button {
                            Task {
                                await viewModel.saveToOriginalSource()
                            }
                        } label: {
                            Label("Save to Photos", systemImage: "photo.on.rectangle")
                        }
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label("Clear File", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                
                if viewModel.hasChanges {
                    Button("Apply") {
                        Task {
                            await viewModel.applyCurrentChanges()
                        }
                    }
                    .bold()
                }
            }
        }
        .sheet(isPresented: $showPrivacyPresets) {
            PrivacyPresetsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = viewModel.getExportURL() {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showMetadataTextSheet) {
            MetadataTextView(viewModel: viewModel)
        }
        .sheet(isPresented: $showEditValueSheet) {
            if let item = editingItem {
                EditMetadataValueView(
                    item: item,
                    newValue: $editValue,
                    onSave: { newVal in
                        Task {
                            await viewModel.editMetadataValue(for: item, newValue: newVal)
                        }
                        showEditValueSheet = false
                    },
                    onCancel: {
                        showEditValueSheet = false
                    }
                )
            }
        }
        .alert("Clear File?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                viewModel.clear()
            }
        } message: {
            Text("This will close the current file. Any unsaved changes will be lost.")
        }
        .overlay {
            if viewModel.isLoading || viewModel.isProcessing {
                LoadingOverlay(
                    message: viewModel.isProcessing ? "Processing..." : "Loading...",
                    progress: viewModel.processingProgress
                )
            }
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(width: 80)
            .padding(.vertical, 10)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - File Preview Section

struct FilePreviewSection: View {
    @ObservedObject var viewModel: MetadataEditorViewModel
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.05)
            
            if let image = viewModel.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(8)
            } else {
                VStack {
                    Image(systemName: fileTypeIcon)
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text(viewModel.fileType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // File info overlay
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.selectedFileURL?.lastPathComponent ?? "Unknown")
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            if let size = viewModel.fileSize {
                                Text(size)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text(viewModel.fileSource.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2))
                                .foregroundColor(.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Spacer()
                    
                    if viewModel.selectedCount > 0 {
                        Badge(count: viewModel.selectedCount, color: .red)
                    }
                    
                    if viewModel.modifiedCount > 0 {
                        Badge(count: viewModel.modifiedCount, color: .blue)
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
            }
        }
    }
    
    private var fileTypeIcon: String {
        switch viewModel.fileType {
        case .image:
            return "photo"
        case .video:
            return "video"
        case .livePhoto:
            return "livephoto"
        case .unknown:
            return "doc"
        }
    }
}

// MARK: - Badge

struct Badge: View {
    let count: Int
    var color: Color = .accentColor
    
    var body: some View {
        Text("\(count)")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(minWidth: 20, minHeight: 20)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - Metadata List View

struct MetadataListView: View {
    @ObservedObject var viewModel: MetadataEditorViewModel
    let onEdit: (MetadataItem) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBar(text: $viewModel.searchQuery)
                .padding(.horizontal)
                .padding(.bottom, 8)
            
            if viewModel.filteredMetadataItems.isEmpty {
                EmptyMetadataView()
            } else {
                List {
                    ForEach(viewModel.filteredMetadataItems) { item in
                        MetadataRow(
                            item: item,
                            isSelected: item.isSelected
                        ) {
                            viewModel.toggleSelection(for: item)
                        } onEdit: {
                            if item.isEditable {
                                onEdit(item)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Category List View

struct CategoryListView: View {
    @ObservedObject var viewModel: MetadataEditorViewModel
    
    var body: some View {
        List(viewModel.categories, id: \.self) { category in
            NavigationLink {
                CategoryDetailView(viewModel: viewModel, category: category)
            } label: {
                CategoryRow(
                    category: category,
                    count: viewModel.metadataByCategory[category]?.count ?? 0,
                    selectedCount: selectedCount(in: category)
                )
            }
        }
        .listStyle(.plain)
    }
    
    private func selectedCount(in category: MetadataCategory) -> Int {
        viewModel.metadataItems
            .filter { $0.category == category && $0.isSelected }
            .count
    }
}

// MARK: - Category Detail View

struct CategoryDetailView: View {
    @ObservedObject var viewModel: MetadataEditorViewModel
    let category: MetadataCategory
    
    var items: [MetadataItem] {
        viewModel.metadataItems.filter { $0.category == category }
    }
    
    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    MetadataRow(
                        item: item,
                        isSelected: item.isSelected
                    ) {
                        viewModel.toggleSelection(for: item)
                    } onEdit: {
                        // Edit not available in category view
                    }
                }
            } header: {
                HStack {
                    Text("\(items.count) items")
                    Spacer()
                    Button("Select All") {
                        viewModel.selectAll(in: category)
                    }
                    .font(.caption)
                }
            }
        }
        .navigationTitle(category.rawValue)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Deselect All") {
                    viewModel.deselectAll(in: category)
                }
                .disabled(items.filter(\.isSelected).isEmpty)
            }
        }
    }
}

// MARK: - Metadata Row

struct MetadataRow: View {
    let item: MetadataItem
    let isSelected: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.red : .secondary)
                .font(.title3)
                .onTapGesture {
                    onToggle()
                }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if item.hasChanges {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                    }
                }
                
                Text(item.displayValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Edit button for editable items - Bigger and more visible
            if item.isEditable {
                Button(action: onEdit) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Edit")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            
            // Category indicator
            Image(systemName: item.category.icon)
                .foregroundStyle(categoryColor)
                .font(.caption)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
        .opacity(item.isEditable ? 1.0 : 0.5)
    }
    
    private var categoryColor: Color {
        switch item.category {
        case .location: return .red
        case .camera: return .blue
        case .date: return .green
        case .author: return .purple
        case .copyright: return .orange
        case .software: return .gray
        case .description: return .cyan
        case .technical: return .indigo
        case .other: return .teal
        }
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: MetadataCategory
    let count: Int
    let selectedCount: Int
    
    var body: some View {
        HStack {
            Image(systemName: category.icon)
                .foregroundStyle(categoryColor)
                .frame(width: 32, height: 32)
                .background(categoryColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.body)
                
                Text("\(count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if selectedCount > 0 {
                Text("\(selectedCount)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
    
    private var categoryColor: Color {
        switch category {
        case .location: return .red
        case .camera: return .blue
        case .date: return .green
        case .author: return .purple
        case .copyright: return .orange
        case .software: return .gray
        case .description: return .cyan
        case .technical: return .indigo
        case .other: return .teal
        }
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search metadata...", text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Empty Metadata View

struct EmptyMetadataView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Metadata Found")
                .font(.headline)
            
            Text("This file doesn't contain any extractable metadata, or your search didn't match any items.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let message: String
    let progress: Double
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if progress > 0 {
                    ProgressView(value: progress)
                        .frame(width: 200)
                }
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Metadata Text View

struct MetadataTextView: View {
    @ObservedObject var viewModel: MetadataEditorViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(viewModel.metadataText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Metadata Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(
                        item: viewModel.metadataText,
                        subject: Text("Metadata Report"),
                        message: Text("Metadata for \(viewModel.selectedFileURL?.lastPathComponent ?? "file")")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

// MARK: - Edit Metadata Value View

struct EditMetadataValueView: View {
    let item: MetadataItem
    @Binding var newValue: String
    let onSave: (Any) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Metadata Key") {
                    Text(item.key)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Current Value") {
                    Text(item.displayValue)
                        .foregroundStyle(.secondary)
                }
                
                Section("New Value") {
                    TextEditor(text: $newValue)
                        .frame(minHeight: 44)
                }
            }
            .navigationTitle("Edit Value")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(newValue)
                    }
                    .bold()
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    MetadataEditorView(viewModel: MetadataEditorViewModel())
}
