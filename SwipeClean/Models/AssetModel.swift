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
        self.thumbnail = UIImage(named: id)
        self.swipeStackImage = UIImage(named: id)
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
