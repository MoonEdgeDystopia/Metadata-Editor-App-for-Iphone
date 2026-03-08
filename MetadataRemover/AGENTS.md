# MetadataRemover Project

## Project Overview

MetadataRemover is an iOS application that allows users to view, manipulate, and remove metadata from photos and videos. The app helps protect user privacy by removing sensitive information embedded in media files, such as GPS location, camera information, and personal details.

- **Bundle Identifier**: `name.danielsantosmendez.MetadataRemover`
- **Version**: 1.0
- **Development Team**: 38X539SLX8
- **Author**: Daniel Santos Mendez

## Technology Stack

- **Language**: Swift 5.0 with modern concurrency (async/await)
- **UI Framework**: SwiftUI
- **IDE**: Xcode 26.1.1 (or later)
- **Minimum iOS Version**: 26.1
- **Supported Devices**: iPhone and iPad
- **Concurrency**: Swift Concurrency with MainActor default isolation

## Project Structure

```
MetadataRemover/
├── MetadataRemover/                    # Main application source
│   ├── MetadataRemoverApp.swift        # App entry point (@main)
│   ├── Models/                         # Data models
│   │   └── MetadataItem.swift          # Metadata item models, categories, presets
│   ├── Services/                       # Business logic services
│   │   ├── MetadataService.swift       # Unified metadata service
│   │   ├── ImageMetadataService.swift  # EXIF metadata handling
│   │   └── VideoMetadataService.swift  # Video metadata handling
│   ├── ViewModels/                     # SwiftUI view models
│   │   └── MetadataEditorViewModel.swift # Main editor view model
│   ├── Views/                          # SwiftUI views
│   │   ├── ContentView.swift           # Main content view with file picker
│   │   ├── MetadataEditorView.swift    # Metadata editing interface
│   │   └── PrivacyPresetsView.swift    # Privacy preset selection
│   ├── Utilities/                      # Helper utilities
│   │   └── Extensions.swift            # Swift extensions
│   └── Assets.xcassets/                # Image and color assets
├── MetadataRemoverTests/               # Unit tests
├── MetadataRemoverUITests/             # UI tests
└── MetadataRemover.xcodeproj/          # Xcode project configuration
```

## Features

### Core Features
1. **File Selection**: Select photos/videos from Photos library or Files app
2. **Metadata Visualization**: View all metadata organized by categories:
   - Location (GPS coordinates)
   - Camera (make, model, settings)
   - Date & Time
   - Author/Creator
   - Copyright
   - Software
   - Description
   - Technical (resolution, format, etc.)

3. **Metadata Removal**: 
   - Select individual metadata items to remove
   - Bulk selection by category
   - Privacy presets for quick removal

4. **Privacy Presets**:
   - Location Only: Removes GPS data
   - Camera Info: Removes camera details
   - Personal Info: Removes author/copyright
   - All Sensitive: Removes location, camera, and personal info
   - Strip All: Removes all metadata

5. **Export**: Save cleaned files with modified metadata

### Supported File Formats
- **Images**: JPEG, PNG, HEIC, TIFF, BMP, GIF, WebP
- **Videos**: MP4, MOV, M4V, AVI, MKV, WMV, FLV, WebM

## Architecture

### MVVM Pattern
The app uses Model-View-ViewModel (MVVM) architecture:
- **Models**: `MetadataItem`, `MetadataCategory`, `PrivacyPreset`
- **Views**: SwiftUI views for UI
- **ViewModels**: `MetadataEditorViewModel` manages state

### Services Layer
- **MetadataService**: Unified interface for all metadata operations
- **ImageMetadataService**: ImageIO-based EXIF handling
- **VideoMetadataService**: AVAsset-based video metadata handling

### Actor Isolation
- Services use Swift actors for thread-safe operations
- MainActor for UI-related properties and methods

## Key Implementation Details

### Metadata Reading
- **Images**: Uses `CGImageSourceCopyPropertiesAtIndex` from ImageIO
- **Videos**: Uses AVAsset metadata APIs with async/await

### Metadata Writing
- **Images**: Creates new image with filtered properties using `CGImageDestination`
- **Videos**: Uses AVAssetExportSession with modified metadata

### Privacy
- All processing happens locally on device
- No network access required
- Temporary files cleaned up on app background/termination

## Build and Test Commands

### Build
```bash
# Build for iOS Simulator
xcodebuild -project MetadataRemover.xcodeproj -scheme MetadataRemover -destination 'platform=iOS Simulator,name=iPhone 17' build

# Build for device
xcodebuild -project MetadataRemover.xcodeproj -scheme MetadataRemover -destination 'generic/platform=iOS' build
```

### Test
```bash
# Run all tests
xcodebuild -project MetadataRemover.xcodeproj -scheme MetadataRemover -destination 'platform=iOS Simulator,name=iPhone 17' test
```

### Clean
```bash
xcodebuild -project MetadataRemover.xcodeproj clean
```

## Dependencies

No external dependencies. The app uses:
- SwiftUI for UI
- ImageIO for image metadata
- AVFoundation for video metadata
- PhotosUI for photo picker
- UniformTypeIdentifiers for file type detection

## Security Considerations

- User Script Sandboxing: Enabled
- ARC: Enabled
- Files are processed in isolated temporary directories
- Security-scoped resources properly handled for file access
