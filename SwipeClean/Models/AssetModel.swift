//
//  AssetModel.swift
//  SwipeClean
//
//  Created by Apps4World on 1/3/25.
//

import UIKit
import Foundation

/// A model that represents a photo gallery asset (photo, video, live photo)
class AssetModel: Identifiable {
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
}

/// Append asset if needed
extension Array where Element == AssetModel {
    mutating func appendIfNeeded(_ model: AssetModel) {
        if !contains(where: { $0.id == model.id }) {
            append(model)
        }
    }
}
