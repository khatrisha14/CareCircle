import Foundation
import UIKit

// MARK: - Local routine photo storage (Documents/routines/)

final class ImageStorageService {
    static let shared = ImageStorageService()

    private let fileManager = FileManager.default
    private let compressionQuality: CGFloat = 0.7

    private var routinesDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("routines", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private init() {}

    /// Saves image to Documents/routines/{UUID}.jpg. Returns filename (e.g. "ABC123.jpg") for storing in model.
    func saveImage(_ image: UIImage) -> String {
        let filename = UUID().uuidString + ".jpg"
        let url = routinesDirectory.appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: compressionQuality) else { return filename }
        try? data.write(to: url)
        return filename
    }

    /// Loads image from Documents/routines/ if path is a filename.
    func loadImage(from path: String) -> UIImage? {
        guard !path.isEmpty else { return nil }
        let url = routinesDirectory.appendingPathComponent(path)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Deletes file at Documents/routines/{path}. Call when routine is deleted.
    func deleteImage(at path: String) {
        guard !path.isEmpty else { return }
        let url = routinesDirectory.appendingPathComponent(path)
        try? fileManager.removeItem(at: url)
    }
}
