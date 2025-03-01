import UIKit
import Foundation

/// A model that represents a photo gallery asset (photo, video, live photo)
class AssetModel: Identifiable, Equatable {
    let id: String
    let month: CalendarMonth
    var thumbnail: UIImage?
    var swipeStackImage: UIImage?
    var creationDate: String?
    
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
}

/// Append asset if needed
extension Array where Element == AssetModel {
    mutating func appendIfNeeded(_ model: AssetModel) {
        if !contains(where: { $0.id == model.id }) {
            append(model)
        }
    }
}
