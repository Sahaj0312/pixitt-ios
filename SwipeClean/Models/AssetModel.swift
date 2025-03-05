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
    
    // Static dictionary to track last swiped date for each month and year
    static var lastSwipedDates: [String: Date] = [:]
    private static let lastSwipedDatesKey = "lastSwipedDates"
    
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
    
    /// Create a key for the month and year
    static func keyForMonthYear(month: CalendarMonth, year: Int) -> String {
        return "\(month.rawValue)_\(year)"
    }
    
    /// Update the last swiped date for a month and year
    static func updateLastSwipedDate(for month: CalendarMonth, year: Int) {
        let key = keyForMonthYear(month: month, year: year)
        lastSwipedDates[key] = Date()
        saveLastSwipedDates()
    }
    
    /// Get formatted time since last swipe for a month and year
    static func formattedTimeSinceLastSwipe(for month: CalendarMonth, year: Int) -> String? {
        let key = keyForMonthYear(month: month, year: year)
        guard let lastSwipedDate = lastSwipedDates[key] else {
            return nil
        }
        
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: lastSwipedDate, to: now)
        
        if let year = components.year, year > 0 {
            return year == 1 ? "Cleaned 1 year ago" : "Cleaned \(year) years ago"
        } else if let month = components.month, month > 0 {
            return month == 1 ? "Cleaned 1 month ago" : "Cleaned \(month) months ago"
        } else if let day = components.day, day > 0 {
            if day == 1 {
                return "Cleaned yesterday"
            } else {
                return "Cleaned \(day) days ago"
            }
        } else if let hour = components.hour, hour > 0 {
            return hour == 1 ? "Cleaned 1 hour ago" : "Cleaned \(hour) hours ago"
        } else if let minute = components.minute, minute > 0 {
            return minute == 1 ? "Cleaned 1 minute ago" : "Cleaned \(minute) minutes ago"
        } else {
            return "Cleaned just now"
        }
    }
    
    /// Save last swiped dates to UserDefaults
    static func saveLastSwipedDates() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var dateStrings: [String: String] = [:]
        for (key, date) in lastSwipedDates {
            dateStrings[key] = dateFormatter.string(from: date)
        }
        
        UserDefaults.standard.set(dateStrings, forKey: lastSwipedDatesKey)
    }
    
    /// Load last swiped dates from UserDefaults
    static func loadLastSwipedDates() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        guard let dateStrings = UserDefaults.standard.dictionary(forKey: lastSwipedDatesKey) as? [String: String] else {
            return
        }
        
        for (key, dateString) in dateStrings {
            if let date = dateFormatter.date(from: dateString) {
                lastSwipedDates[key] = date
            }
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
