import UIKit
import Foundation

/// A model that represents a photo gallery asset (photo, video, live photo)
class AssetModel: Identifiable, Equatable {
    let id: String
    let month: CalendarMonth
    var thumbnail: UIImage?
    var swipeStackImage: UIImage?
    var creationDate: String?
    var duration: TimeInterval = 0
    var isVideo: Bool { duration > 0 }
    
    init(id: String, month: CalendarMonth) {
        self.id = id
        self.month = month
        // Don't load images directly in initializer to avoid main thread I/O
        // Images should be set asynchronously after initialization
    }
    
    /// Load images asynchronously on a background queue
    func loadImages(completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let thumbnail = UIImage(named: self.id)
            let stackImage = UIImage(named: self.id)
            
            DispatchQueue.main.async {
                self.thumbnail = thumbnail
                self.swipeStackImage = stackImage
                completion?()
            }
        }
    }
    
    /// Implement Equatable protocol - compare assets by their ID
    static func == (lhs: AssetModel, rhs: AssetModel) -> Bool {
        return lhs.id == rhs.id
    }
    
    /// Format duration as string (e.g. "1:23")
    var formattedDuration: String {
        guard duration > 0 else { return "" }
        
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
        }
    }
}

/// Append asset if needed
extension Array where Element == AssetModel {
    mutating func appendIfNeeded(_ model: AssetModel) {
        if !contains(where: { $0.id == model.id }) {
            append(model)
        }
    }
}
