//
//  MetadataItem.swift
//  MetadataRemover
//
//  Created by Daniel Santos Mendez on 07/03/26.
//

import Foundation

/// Represents a single metadata item with its properties
struct MetadataItem: Identifiable {
    let id = UUID()
    let key: String
    let displayName: String
    let originalValue: Any?
    var editedValue: Any?
    let category: MetadataCategory
    var isSelected: Bool = false
    var isEditable: Bool = true
    
    var currentValue: Any? {
        editedValue ?? originalValue
    }
    
    var displayValue: String {
        let value = currentValue
        guard let val = value else { return "N/A" }
        if let stringValue = val as? String {
            return stringValue.isEmpty ? "Empty" : stringValue
        }
        if let dateValue = val as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            return formatter.string(from: dateValue)
        }
        if let numberValue = val as? NSNumber {
            return numberValue.stringValue
        }
        if let dataValue = val as? Data {
            return "\(dataValue.count) bytes"
        }
        return String(describing: val)
    }
    
    var hasChanges: Bool {
        editedValue != nil
    }
}

/// Source type for tracking where the file came from
enum FileSource: String {
    case photosLibrary = "Photos Library"
    case files = "Files"
    case unknown = "Unknown"
}

/// Categories for organizing metadata
enum MetadataCategory: String, CaseIterable, Identifiable {
    case location = "Location"
    case camera = "Camera"
    case date = "Date & Time"
    case author = "Author"
    case copyright = "Copyright"
    case software = "Software"
    case description = "Description"
    case technical = "Technical"
    case other = "Other"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .location: return "location.fill"
        case .camera: return "camera.fill"
        case .date: return "calendar"
        case .author: return "person.fill"
        case .copyright: return "c.circle.fill"
        case .software: return "laptopcomputer"
        case .description: return "text.alignleft"
        case .technical: return "gearshape.fill"
        case .other: return "tag.fill"
        }
    }
    
    var color: String {
        switch self {
        case .location: return "red"
        case .camera: return "blue"
        case .date: return "green"
        case .author: return "purple"
        case .copyright: return "orange"
        case .software: return "gray"
        case .description: return "cyan"
        case .technical: return "indigo"
        case .other: return "teal"
        }
    }
}

/// Supported file types
enum FileType: String, CaseIterable {
    case image = "Image"
    case video = "Video"
    case livePhoto = "Live Photo"
    case unknown = "Unknown"
    
    var supportedExtensions: [String] {
        switch self {
        case .image:
            return ["jpg", "jpeg", "png", "heic", "tiff", "tif", "bmp", "gif", "webp"]
        case .video:
            return ["mp4", "mov", "m4v", "avi", "mkv", "wmv", "flv", "webm"]
        case .livePhoto:
            return ["heic", "jpg", "mov"]
        case .unknown:
            return []
        }
    }
    
    static func from(url: URL) -> FileType {
        let ext = url.pathExtension.lowercased()
        for type in [.image, .video] as [FileType] {
            if type.supportedExtensions.contains(ext) {
                return type
            }
        }
        return .unknown
    }
}

/// Privacy preset configurations
enum PrivacyPreset: String, CaseIterable, Identifiable {
    case locationOnly = "Location Only"
    case cameraInfo = "Camera Info"
    case personalInfo = "Personal Info"
    case allSensitive = "All Sensitive"
    case stripAll = "Strip All"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .locationOnly:
            return "Remove GPS coordinates and location data only"
        case .cameraInfo:
            return "Remove camera make, model, and settings"
        case .personalInfo:
            return "Remove author, copyright, and creator information"
        case .allSensitive:
            return "Remove location, camera, and personal information"
        case .stripAll:
            return "Remove all metadata (maximum privacy)"
        }
    }
    
    var icon: String {
        switch self {
        case .locationOnly: return "location.slash.fill"
        case .cameraInfo: return "camera.badge.ellipsis"
        case .personalInfo: return "person.crop.circle.badge.xmark"
        case .allSensitive: return "shield.checkerboard"
        case .stripAll: return "nosign"
        }
    }
    
    /// Returns the keys that should be removed for this preset
    func keysToRemove() -> [String] {
        switch self {
        case .locationOnly:
            return PrivacyKeys.location
        case .cameraInfo:
            return PrivacyKeys.camera
        case .personalInfo:
            return PrivacyKeys.personal
        case .allSensitive:
            return PrivacyKeys.location + PrivacyKeys.camera + PrivacyKeys.personal
        case .stripAll:
            return PrivacyKeys.all
        }
    }
}

/// Common metadata keys organized by category
struct PrivacyKeys {
    static let location = [
        "GPSLatitude", "GPSLongitude", "GPSLatitudeRef", "GPSLongitudeRef",
        "GPSAltitude", "GPSAltitudeRef", "GPSTimeStamp", "GPSDateStamp",
        "GPSProcessingMethod", "GPSAreaInformation", "GPSMapDatum",
        "GPSDestLatitude", "GPSDestLongitude", "GPSDestBearing",
        "{GPS}", "com.apple.quicktime.location.ISO6709",
        "com.apple.quicktime.location.accuracy.horizontal",
        "com.apple.quicktime.location.accuracy.vertical"
    ]
    
    static let camera = [
        "Make", "Model", "LensMake", "LensModel",
        "FNumber", "ExposureTime", "ISOSpeedRatings", "FocalLength",
        "FocalLengthIn35mmFilm", "ExposureProgram", "MeteringMode",
        "Flash", "WhiteBalance", "SceneType", "LensSpecification",
        "CameraOwnerName", "BodySerialNumber", "LensSerialNumber",
        "{ExifAux}", "com.apple.quicktime.make", "com.apple.quicktime.model"
    ]
    
    static let personal = [
        "Artist", "Copyright", "ImageDescription", "XPAuthor",
        "XPComment", "XPKeywords", "XPSubject", "OwnerName",
        "Author", "Creator", "Publisher", "Contributor",
        "com.apple.quicktime.author", "com.apple.quicktime.copyright",
        "com.apple.quicktime.displayname", "com.apple.quicktime.title"
    ]
    
    static let software = [
        "Software", "ProcessingSoftware", "HostComputer",
        "com.apple.quicktime.software"
    ]
    
    static let date = [
        "DateTime", "DateTimeOriginal", "DateTimeDigitized",
        "SubsecTime", "SubsecTimeOriginal", "SubsecTimeDigitized",
        "com.apple.quicktime.creationdate", "com.apple.quicktime.modificationdate"
    ]
    
    static let all = location + camera + personal + software + date + [
        "Orientation", "XResolution", "YResolution", "ResolutionUnit",
        "ColorSpace", "PixelXDimension", "PixelYDimension",
        "Compression", "BitsPerSample", "PhotometricInterpretation",
        "SamplesPerPixel", "RowsPerStrip", "PlanarConfiguration"
    ]
}

/// Result of metadata operations
enum MetadataOperationResult {
    case success(URL)
    case failure(Error)
    case cancelled
}

/// Errors that can occur during metadata operations
enum MetadataError: LocalizedError {
    case unsupportedFileType
    case failedToReadMetadata
    case failedToWriteMetadata
    case failedToSaveFile
    case noMetadataFound
    case invalidData
    case permissionDenied
    case photosLibraryAccessDenied
    case failedToSaveToPhotos
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "This file type is not supported"
        case .failedToReadMetadata:
            return "Failed to read metadata from file"
        case .failedToWriteMetadata:
            return "Failed to modify metadata"
        case .failedToSaveFile:
            return "Failed to save the modified file"
        case .noMetadataFound:
            return "No metadata found in this file"
        case .invalidData:
            return "The file contains invalid data"
        case .permissionDenied:
            return "Permission denied to access the file"
        case .photosLibraryAccessDenied:
            return "Access to Photos library was denied"
        case .failedToSaveToPhotos:
            return "Failed to save to Photos library"
        }
    }
}
