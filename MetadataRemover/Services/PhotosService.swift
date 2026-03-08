//
//  PhotosService.swift
//  MetadataRemover
//
//  Created by Daniel Santos Mendez on 07/03/26.
//

import Foundation
import Photos
import UIKit

/// Service for saving files back to Photos library
actor PhotosService {
    
    static let shared = PhotosService()
    
    /// Saves an image to the Photos library
    func saveImageToPhotos(_ imageURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                completion(.failure(MetadataError.photosLibraryAccessDenied))
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: imageURL, options: nil)
            }) { success, error in
                if success {
                    completion(.success(()))
                } else if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.failure(MetadataError.failedToSaveToPhotos))
                }
            }
        }
    }
    
    /// Saves a video to the Photos library
    func saveVideoToPhotos(_ videoURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                completion(.failure(MetadataError.photosLibraryAccessDenied))
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .video, fileURL: videoURL, options: nil)
            }) { success, error in
                if success {
                    completion(.success(()))
                } else if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.failure(MetadataError.failedToSaveToPhotos))
                }
            }
        }
    }
    
    /// Checks if Photos library access is authorized
    func checkAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }
    
    /// Saves file to Photos based on file type
    func saveToPhotos(_ url: URL, fileType: FileType) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            switch fileType {
            case .image, .livePhoto:
                saveImageToPhotos(url) { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            case .video:
                saveVideoToPhotos(url) { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            case .unknown:
                continuation.resume(throwing: MetadataError.unsupportedFileType)
            }
        }
    }
}
