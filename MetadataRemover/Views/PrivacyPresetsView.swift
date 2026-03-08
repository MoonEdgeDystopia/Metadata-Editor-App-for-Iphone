//
//  PrivacyPresetsView.swift
//  MetadataRemover
//
//  Created by Daniel Santos Mendez on 07/03/26.
//

import SwiftUI

struct PrivacyPresetsView: View {
    
    @ObservedObject var viewModel: MetadataEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirmation = false
    @State private var selectedPreset: PrivacyPreset?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Privacy presets allow you to quickly remove common categories of sensitive metadata with one tap.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section("Presets") {
                    ForEach(PrivacyPreset.allCases) { preset in
                        PresetRow(
                            preset: preset,
                            isRecommended: preset == .allSensitive
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPreset = preset
                            showConfirmation = true
                        }
                    }
                }
                
                Section("What Gets Removed") {
                    ForEach(PrivacyPreset.allCases) { preset in
                        DisclosureGroup(preset.rawValue) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(preset.keysToRemove(), id: \.self) { key in
                                    HStack {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                            .font(.caption)
                                        Text(key)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Privacy Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Apply Preset?", isPresented: $showConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Apply") {
                    if let preset = selectedPreset {
                        Task {
                            await viewModel.applyPrivacyPreset(preset)
                            dismiss()
                        }
                    }
                }
            } message: {
                if let preset = selectedPreset {
                    Text("This will remove \(preset.keysToRemove().count) metadata items from your file. This action cannot be undone.")
                }
            }
        }
    }
}

// MARK: - Preset Row

struct PresetRow: View {
    let preset: PrivacyPreset
    let isRecommended: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: preset.icon)
                .font(.system(size: 24))
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(preset.rawValue)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if isRecommended {
                        Text("Recommended")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }
                }
                
                Text(preset.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                Text("\(preset.keysToRemove().count) items")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
    
    private var iconColor: Color {
        switch preset {
        case .locationOnly:
            return .red
        case .cameraInfo:
            return .blue
        case .personalInfo:
            return .purple
        case .allSensitive:
            return .green
        case .stripAll:
            return .orange
        }
    }
}

// MARK: - Preset Detail View

struct PresetDetailView: View {
    let preset: PrivacyPreset
    
    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: preset.icon)
                            .font(.system(size: 48))
                            .foregroundStyle(iconColor)
                        
                        Text(preset.rawValue)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(preset.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)
            
            Section("Metadata Keys Removed") {
                ForEach(preset.keysToRemove(), id: \.self) { key in
                    HStack {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                        
                        Text(key)
                            .font(.subheadline)
                    }
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Removes metadata permanently", systemImage: "exclamationmark.triangle")
                    Label("Original file is not modified", systemImage: "doc.badge.plus")
                    Label("Creates a new cleaned copy", systemImage: "arrow.right.doc.on.clipboard")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Preset Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var iconColor: Color {
        switch preset {
        case .locationOnly:
            return .red
        case .cameraInfo:
            return .blue
        case .personalInfo:
            return .purple
        case .allSensitive:
            return .green
        case .stripAll:
            return .orange
        }
    }
}

#Preview {
    PrivacyPresetsView(viewModel: MetadataEditorViewModel())
}
