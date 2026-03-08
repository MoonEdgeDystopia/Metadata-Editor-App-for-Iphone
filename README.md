# Metadata Remover for iOS

A privacy-focused iOS application that allows you to view, edit, and remove metadata from your photos and videos. All processing happens locally on your device - your files never leave your phone.

![Platform](https://img.shields.io/badge/platform-iOS%2016+-blue.svg)
![Language](https://img.shields.io/badge/language-Swift%205.0-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## 📱 Features

### 🔍 View Metadata
- Browse all metadata from your photos and videos
- Organized by categories: Location, Camera, Date, Author, Copyright, Software, Description, Technical
- Search through metadata items
- View metadata as formatted text report

### ✏️ Edit Metadata
- Tap any editable metadata value to modify it
- Change text values like Author, Copyright, Description
- Changes are applied when you save

### 🗑️ Remove Metadata
- Select individual metadata items to remove
- Bulk select by category
- Privacy presets for quick removal:
  - **Location Only**: Removes GPS coordinates
  - **Camera Info**: Removes camera make, model, settings
  - **Personal Info**: Removes author, copyright information
  - **All Sensitive**: Removes location, camera, and personal info
  - **Strip All**: Removes all metadata (maximum privacy)

### 💾 Save Options
- Save modified images back to Photos library
- Share via standard iOS share sheet
- Export metadata text report

### 🔒 Privacy First
- **100% Local Processing**: No internet connection required
- **No Data Collection**: Your files never leave your device
- **No Analytics**: We don't track your usage

## 📸 Supported Formats

### Images
- JPEG/JPG
- PNG
- HEIC/HEIF
- TIFF
- BMP
- GIF
- WebP

### Videos
- MP4
- MOV
- M4V
- AVI
- MKV
- WMV
- FLV
- WebM

## 🚀 Getting Started

### Requirements
- iOS 16.0 or later
- iPhone or iPad
- Xcode 14+ (for building from source)

### Installation

#### From App Store (Coming Soon)
The app will be available on the App Store soon.

#### Build from Source
1. Clone the repository:
   ```bash
   git clone https://github.com/MoonEdgeDystopia/Metadata-Editor-App-for-Iphone.git
   cd Metadata-Editor-App-for-Iphone
   ```

2. Open in Xcode:
   ```bash
   open MetadataRemover.xcodeproj
   ```

3. Build and run:
   - Select your target device (iPhone/iPad or Simulator)
   - Press Cmd+R to build and run

## 📖 How to Use

### Removing Metadata from a Photo

1. **Select a Photo**
   - Tap "Select from Photos" to choose from your library
   - Or tap "Browse Files" to select from Files app

2. **View Metadata**
   - Browse through metadata organized by categories
   - Use the search bar to find specific items
   - Tap "View Text" to see all metadata as text

3. **Select Items to Remove**
   - Tap the circle next to any metadata item to select it for removal
   - Selected items show a red checkmark
   - Use "Select All" in the menu to select all items in a category

4. **Apply Changes**
   - Tap the "Apply" button to process the changes
   - The app creates a new file with the selected metadata removed

5. **Save**
   - Tap "Save to Photos" to save back to your library
   - Or use "Share" to send via other apps

### Editing a Metadata Value

1. Find the metadata item you want to edit
2. Tap the blue "Edit" button next to it
3. Enter the new value
4. Tap "Save"

### Using Privacy Presets

1. Tap the menu button (three dots)
2. Select "Privacy Presets"
3. Choose a preset:
   - **Location Only**: Quick GPS removal
   - **Camera Info**: Remove camera identification
   - **Personal Info**: Remove author data
   - **All Sensitive**: Comprehensive privacy protection
   - **Strip All**: Maximum privacy
4. Tap "Apply" on the confirmation dialog

## 🏗️ Architecture

The app is built with:
- **SwiftUI**: Modern declarative UI framework
- **MVVM Architecture**: Clean separation of concerns
- **Swift Concurrency**: Async/await for modern asynchronous code
- **ImageIO**: For reading/writing image EXIF metadata
- **AVFoundation**: For video metadata handling

### Project Structure
```
MetadataRemover/
├── Models/              # Data models
├── Services/            # Business logic
│   ├── ImageMetadataService.swift
│   ├── VideoMetadataService.swift
│   ├── MetadataService.swift
│   └── PhotosService.swift
├── ViewModels/          # State management
├── Views/               # SwiftUI views
└── Utilities/           # Helper extensions
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built with ❤️ by Daniel Santos Mendez
- Icons by [SF Symbols](https://developer.apple.com/sf-symbols/)

## 📧 Contact

For questions or support, please open an issue on GitHub.

---

**Privacy Note**: This app was created to help users protect their privacy. We believe your data belongs to you, and you should have full control over what information is embedded in your files.
