import Photos
import SwiftUI
import PhotosUI
import CoreData
import Foundation

/// Main data manager for the app
class DataManager: NSObject, ObservableObject {
    
    /// Dynamic properties that the UI will react to
    @Published var fullScreenMode: FullScreenMode?
    @Published var selectedTab: CustomTabBarItem = .discover
    @Published var galleryAssets: [AssetModel] = [AssetModel]()
    @Published var didGrantPermissions: Bool = false
    @Published var didProcessAssets: Bool = false
    @Published var onThisDateHeaderImage: UIImage?
    @Published var assetsSwipeStack: [AssetModel] = [AssetModel]()
    @Published var removeStackAssets: [AssetModel] = [AssetModel]()
    @Published var keepStackAssets: [AssetModel] = [AssetModel]()
    @Published var swipeStackLoadMore: Bool = false
    @Published var swipeStackTitle: String = AppConfig.swipeStackOnThisDateTitle
   
    /// Dynamic properties that the UI will react to AND store values in UserDefaults
    @AppStorage("freePhotosStackCount") var freePhotosStackCount: Int = 0
    @AppStorage("didShowOnboardingFlow") var didShowOnboardingFlow: Bool = false
    @AppStorage(AppConfig.premiumVersion) var isPremiumUser: Bool = false {
        didSet { Interstitial.shared.isPremiumUser = isPremiumUser }
    }
    
    // Persistence key for photo bin assets
    private let photoBinPersistenceKey = "photoBinAssetIDs"
    
    /// Core Data container with the database model
    private let container: NSPersistentContainer = NSPersistentContainer(name: "Database")
    
    /// Photo Library properties
    private let imageManager: PHImageManager = PHImageManager()
    private var fetchResult: PHFetchResult<PHAsset>!
    private var assetsByMonth: [CalendarMonth: [PHAsset]] = [CalendarMonth: [PHAsset]]()
    var assetsByYearMonth: [Int: [CalendarMonth: [PHAsset]]] = [:]
    
    /// Default initializer
    override init() {
        super.init()
        prepareCoreData()
        configurePlaceholderAssets()
        checkAuthorizationStatus()
    }
    
    /// Sorted months based on current date
    var sortedMonths: [CalendarMonth] {
        CalendarMonth.allCases
    }
    
    /// Get sorted years in descending order
    var sortedYears: [Int] {
        Array(assetsByYearMonth.keys).sorted(by: >)
    }
    
    /// Get sorted months for a given year that have photos
    func sortedMonths(for year: Int) -> [CalendarMonth] {
        guard let yearData = assetsByYearMonth[year] else { return [] }
        return yearData.keys.sorted { month1, month2 in
            let monthIndex1 = CalendarMonth.allCases.firstIndex(of: month1) ?? 0
            let monthIndex2 = CalendarMonth.allCases.firstIndex(of: month2) ?? 0
            return monthIndex1 < monthIndex2
        }
    }
}

// MARK: - Onboarding implementation
extension DataManager {
    func getStarted() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
            DispatchQueue.main.async {
                self.didShowOnboardingFlow = true
                self.removeStackAssets.removeAll()
                self.keepStackAssets.removeAll()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.checkAuthorizationStatus()
                    Interstitial.shared.loadInterstitial()
                }
            }
        }
    }
    
    /// Check if the user granted permissions to their photo library
    private func checkAuthorizationStatus() {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            DispatchQueue.main.async {
                PHPhotoLibrary.shared().register(self)
                self.didGrantPermissions = true
                self.fetchLibraryAssets()
            }
        default:
            DispatchQueue.main.async {
                self.didGrantPermissions = false
            }
        }
    }
}

// MARK: - Discover Tab implementation
extension DataManager {
    private func configurePlaceholderAssets() {
        CalendarMonth.allCases.forEach { month in
            var placeholders: [AssetModel] = [AssetModel]()
            for index in 0..<3 {
                placeholders.append(.init(id: "placeholder-\(index)-\(month.rawValue)", month: month))
            }
            galleryAssets.append(contentsOf: placeholders)
        }
    }
    
    /// Get up to 3 assets for a given month
    /// - Parameter month: month to get the assets for Discover tab
    /// - Returns: returns up to 3 assets (or placeholders)
    func assetsPreview(for month: CalendarMonth, year: Int) -> [AssetModel] {
        if let assets = assetsByYearMonth[year]?[month]?.prefix(4) {
            return assets.map { asset in
                let assetModel = AssetModel(id: asset.localIdentifier, month: month)
                let assetIdentifier = asset.localIdentifier + "_thumbnail"
                let imageSize = AppConfig.sectionItemThumbnailSize
                requestImage(for: asset, assetIdentifier: assetIdentifier, size: imageSize) { image in
                    assetModel.thumbnail = image
                }
                return assetModel
            }
        }
        return []
    }
    
    /// Get the total number of assets for a given month
    /// - Parameter month: month to get the assets count for
    /// - Returns: returns the number of assets for a month
    func assetsCount(for month: CalendarMonth) -> Int? {
        assetsByMonth[month]?.count
    }
    
    /// Check if the user has photos for this date in current year or previous years
    var hasPhotosOnThisDate: Bool {
        onThisDateHeaderImage != nil
    }
}

// MARK: - Swipe Tab implementation
extension DataManager {
    /// Mark asset as `keep`
    /// - Parameter model: asset model
    func keepAsset(_ model: AssetModel) {
        model.swipeStackImage = nil
        keepStackAssets.appendIfNeeded(model)
        assetsSwipeStack.removeAll(where: { $0.id == model.id })
        guard !model.id.starts(with: "onboarding") else { return }
        freePhotosStackCount += 1
        appendStackAssetsIfNeeded()
        
        // Notify UI to refresh
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    /// Mark asset as `delete`
    /// - Parameter model: asset model
    func deleteAsset(_ model: AssetModel) {
        guard !model.id.starts(with: "onboarding") else {
            removeStackAssets.appendIfNeeded(model)
            assetsSwipeStack.removeAll(where: { $0.id == model.id })
            return
        }
        
        let assetIdentifier: String = model.id
        let imageSize: CGSize = AppConfig.sectionItemThumbnailSize
        if let asset = assetsByMonth.flatMap({ $0.value }).first(where: { $0.localIdentifier == assetIdentifier }) {
            // Update asset counts in the assetsByMonth and assetsByYearMonth dictionaries
            if let creationDate = asset.creationDate {
                let year = Calendar.current.component(.year, from: creationDate)
                let month = creationDate.month
                
                // Remove the asset from assetsByMonth
                if var monthAssets = assetsByMonth[month] {
                    monthAssets.removeAll(where: { $0.localIdentifier == assetIdentifier })
                    assetsByMonth[month] = monthAssets
                }
                
                // Remove the asset from assetsByYearMonth
                if var yearMonths = assetsByYearMonth[year],
                   var monthAssets = yearMonths[month] {
                    monthAssets.removeAll(where: { $0.localIdentifier == assetIdentifier })
                    yearMonths[month] = monthAssets
                    assetsByYearMonth[year] = yearMonths
                }
            }
            
            requestImage(for: asset, assetIdentifier: assetIdentifier, size: imageSize) { image in
                model.thumbnail = image
                model.swipeStackImage = nil
                self.removeStackAssets.appendIfNeeded(model)
                self.assetsSwipeStack.removeAll(where: { $0.id == model.id })
                self.freePhotosStackCount += 1
                self.appendStackAssetsIfNeeded()
                
                // Notify UI to refresh and save state
                DispatchQueue.main.async {
                    // Rebuild gallery assets to ensure counts are updated
                    self.rebuildGalleryAssets()
                    self.objectWillChange.send()
                    self.savePhotoBinState()
                }
            }
        } else {
            presentAlert(title: "Oops!", message: "Something went wrong with this image", primaryAction: .Cancel)
        }
    }
    
    /// Append more assets to the stack
    private func appendStackAssetsIfNeeded() {
        guard assetsSwipeStack.count == 3 else { return }
        let onThisDate: Bool = swipeStackTitle == AppConfig.swipeStackOnThisDateTitle
        let month: CalendarMonth? = CalendarMonth(rawValue: swipeStackTitle.lowercased())
        swipeStackLoadMore = true
        Interstitial.shared.showInterstitialAds()
        DispatchQueue.global(qos: .userInitiated).async {
            self.updateSwipeStack(with: month, onThisDate: onThisDate, switchTabs: false)
            DispatchQueue.main.async { self.swipeStackLoadMore = false }
        }
    }
}

// MARK: - Photo Bin implementation
extension DataManager {
    /// Move a `delete` item back `assetsSwipeStack`
    /// - Parameter model: asset model
    func restoreAsset(_ model: AssetModel) {
        // Find the original asset
        let allAssets = fetchResult.objects(at: IndexSet(integersIn: 0..<fetchResult.count))
        if let asset = allAssets.first(where: { $0.localIdentifier == model.id }),
           let creationDate = asset.creationDate {
            let year = Calendar.current.component(.year, from: creationDate)
            let month = creationDate.month
            
            // Add the asset back to assetsByMonth if it's not already there
            if !assetsByMonth[month, default: []].contains(where: { $0.localIdentifier == model.id }) {
                assetsByMonth[month, default: []].append(asset)
            }
            
            // Add the asset back to assetsByYearMonth if it's not already there
            if !assetsByYearMonth[year, default: [:]][month, default: []].contains(where: { $0.localIdentifier == model.id }) {
                assetsByYearMonth[year, default: [:]][month, default: []].append(asset)
            }
            
            // Remove from removeStackAssets
            removeStackAssets.removeAll(where: { $0.id == model.id })
            
            // Save the updated photo bin state
            savePhotoBinState()
            
            // Notify UI to refresh
            DispatchQueue.main.async {
                // Clear and rebuild gallery assets to ensure counts are updated
                self.rebuildGalleryAssets()
                self.objectWillChange.send()
            }
        } else {
            // If we can't find the asset in the fetch result, just remove it from the bin
            removeStackAssets.removeAll(where: { $0.id == model.id })
            savePhotoBinState()
        }
    }
    
    /// Rebuild gallery assets to ensure proper counts
    private func rebuildGalleryAssets() {
        galleryAssets.removeAll()
        
        for month in CalendarMonth.allCases {
            guard let assets = assetsByMonth[month], !assets.isEmpty else { continue }
            let assetsToAdd = assets.prefix(3)
            for asset in assetsToAdd {
                let assetModel = AssetModel(id: asset.localIdentifier, month: month)
                let assetIdentifier = asset.localIdentifier + "_thumbnail"
                let imageSize = AppConfig.sectionItemThumbnailSize
                requestImage(for: asset, assetIdentifier: assetIdentifier, size: imageSize) { image in
                    assetModel.thumbnail = image
                }
                galleryAssets.append(assetModel)
            }
        }
    }
    
    /// Get PHAssets for deletion by their identifiers
    /// - Parameter identifiers: Array of asset identifiers
    /// - Returns: Array of PHAssets that match the provided identifiers
    func getAssetsForDeletion(identifiers: Set<String>) -> [PHAsset] {
        let allAssets = assetsByMonth.flatMap { $0.value }
        return allAssets.filter { identifiers.contains($0.localIdentifier) }
    }
}

// MARK: - Photo Library implementation
extension DataManager {
    private func fetchLibraryAssets() {
        let allPhotosOptions = PHFetchOptions()
        allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchResult = PHAsset.fetchAssets(with: allPhotosOptions)
        processFetchResult()
    }
    
    /// Process fetch result assets
    private func processFetchResult() {
        // Clear existing data
        assetsByMonth.removeAll()
        assetsByYearMonth.removeAll()
        
        // Process all assets
        fetchResult.enumerateObjects { asset, _, _ in
            guard let creationDate = asset.creationDate else { return }
            let year = Calendar.current.component(.year, from: creationDate)
            self.assetsByMonth[creationDate.month, default: []].append(asset)
            self.assetsByYearMonth[year, default: [:]][creationDate.month, default: []].append(asset)
        }
        
        /// Update the SwipeClean tab with `On This Date` photos by default
        updateSwipeStack(onThisDate: true, switchTabs: false)
        
        /// Add up to 3 assets for each month to `galleryAssets`
        rebuildGalleryAssets()
        
        /// Fetch the image for `On This Date` header
        if let thisDateAsset = assetsByMonth[Date().month]?
            .sorted(by: { $0.creationDate ?? Date() > $1.creationDate ?? Date() })
            .first(where: { $0.creationDate?.string(format: "MM/dd") == Date().string(format: "MM/dd") }) {
            let assetIdentifier = thisDateAsset.localIdentifier + "_onThisDate"
            let imageSize = AppConfig.onThisDateItemSize
            requestImage(for: thisDateAsset, assetIdentifier: assetIdentifier, size: imageSize) { image in
                DispatchQueue.main.async {
                    self.onThisDateHeaderImage = image
                }
            }
        }
        
        /// Load saved photo bin state
        loadPhotoBinState()
        
        /// Show the `Discover` tab
        DispatchQueue.main.async {
            self.didProcessAssets = true
        }
    }
    
    /// Update the `assetsSwipeStack` with selected category
    func updateSwipeStack(with calendarMonth: CalendarMonth? = nil, year: Int? = nil, onThisDate: Bool = false, switchTabs: Bool = true) {
        func appendSwipeStackAsset(_ asset: PHAsset) {
            let assetIdentifier = asset.localIdentifier
            let imageSize = AppConfig.swipeStackItemSize
            requestImage(for: asset, assetIdentifier: assetIdentifier, size: imageSize) { image in
                func appendAsset() {
                    if let assetImage = image {
                        let assetModel = AssetModel(id: asset.localIdentifier, month: Date().month)
                        assetModel.swipeStackImage = assetImage
                        assetModel.creationDate = asset.creationDate?.string(format: "MMMM dd, yyyy")
                        self.assetsSwipeStack.appendIfNeeded(assetModel)
                    }
                }
                if switchTabs { appendAsset() } else {
                    DispatchQueue.main.async { appendAsset() }
                }
            }
        }
        
        func shouldAppendAsset(_ asset: PHAsset) -> Bool {
            let assetIdentifier = asset.localIdentifier
            let isNotInSwipeStack = !assetsSwipeStack.contains { $0.id == assetIdentifier }
            let isNotInRemoveStack = !removeStackAssets.contains { $0.id == assetIdentifier }
            let isNotInKeepStack = !keepStackAssets.contains { $0.id == assetIdentifier }
            return isNotInSwipeStack && isNotInRemoveStack && isNotInKeepStack
        }
        
        var assets: [PHAsset] = [PHAsset]()
        
        if onThisDate {
            assets = assetsByMonth[Date().month]?
                .sorted(by: { $0.creationDate ?? Date() > $1.creationDate ?? Date() })
                .filter({ $0.creationDate?.string(format: "MM/dd") == Date().string(format: "MM/dd") }) ?? []
        } else if let month = calendarMonth, let year = year {
            assets = assetsByYearMonth[year]?[month] ?? []
        }
        
        if switchTabs {
            assetsSwipeStack.removeAll()
            keepStackAssets.removeAll()
            selectedTab = .swipeClean
        }
        
        DispatchQueue.main.async {
            let thisDateTitle: String = AppConfig.swipeStackOnThisDateTitle
            self.swipeStackTitle = onThisDate ? thisDateTitle : calendarMonth?.rawValue.capitalized ?? ""
        }
        
        assets.filter(shouldAppendAsset).prefix(10).forEach { appendSwipeStackAsset($0) }
    }
    
    /// Delete all photos from the bin
    func emptyPhotoBin() {
        let itemsCount: Int = removeStackAssets.count
        presentAlert(title: "Delete Photos", message: "Are you sure you want to delete these \(itemsCount) photos?", primaryAction: .Cancel, secondaryAction: .init(title: "Delete", style: .destructive, handler: { _ in
            let allAssets = self.assetsByMonth.flatMap { $0.value }
            let removeStackAssetIdentifiers = self.removeStackAssets.compactMap { $0.id }
            let assetsToRemove = allAssets.filter { removeStackAssetIdentifiers.contains($0.localIdentifier) }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assetsToRemove as NSArray)
            } completionHandler: { success, error in
                if success {
                    DispatchQueue.main.async {
                        self.removeStackAssets.removeAll()
                        self.savePhotoBinState()
                    }
                } else if let errorMessage = error?.localizedDescription {
                    presentAlert(title: "Oops!", message: errorMessage, primaryAction: .OK)
                }
            }
        }))
    }
}

// MARK: - Handle Photo Library changes
extension DataManager: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let changes = changeInstance.changeDetails(for: fetchResult) else { return }
        DispatchQueue.main.async {
            self.assetsByMonth.removeAll()
            self.assetsSwipeStack.removeAll()
            self.keepStackAssets.removeAll()
            self.fetchResult = changes.fetchResultAfterChanges
            self.processFetchResult()
        }
    }
}

// MARK: - Core Data implementation
extension DataManager {
    private func prepareCoreData() {
        container.loadPersistentStores { _, _ in
            self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
    }
    
    /// Saves the asset image to Core Data
    /// - Parameters:
    ///   - image: asset image to be saved
    ///   - assetIdentifier: asset identifier
    private func saveAsset(image: UIImage?, assetIdentifier: String) {
        guard let assetData = image?.jpegData(compressionQuality: 1) else { return }
        let assetEntity: AssetEntity = AssetEntity(context: container.viewContext)
        assetEntity.assetIdentifier = assetIdentifier
        assetEntity.imageData = assetData
        try? container.viewContext.save()
    }
    
    /// Fetch cached asset image from Core Data
    /// - Parameter assetIdentifier: asset identifier
    /// - Returns: returns the image if available
    private func fetchCachedImage(for assetIdentifier: String) -> UIImage? {
        let fetchRequest: NSFetchRequest<AssetEntity> = AssetEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "assetIdentifier = %@", assetIdentifier)
        if let imageData = try? container.viewContext.fetch(fetchRequest).first?.imageData {
            return UIImage(data: imageData)
        }
        return nil
    }
    
    /// Request image for a given asset
    func requestImage(for asset: PHAsset, assetIdentifier: String, size: CGSize, completion: @escaping (UIImage?) -> Void) -> Bool {
        if let cachedImage = fetchCachedImage(for: assetIdentifier) {
            completion(cachedImage)
            return true
        }
        
        imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: .opportunistic) { image, _ in
            if let image = image {
                self.saveAsset(image: image, assetIdentifier: assetIdentifier)
                completion(image)
            }
        }
        return false
    }
}

// MARK: - Video Handling
extension DataManager {
    /// Check if an asset is a video and return its URL if it is
    /// - Parameters:
    ///   - assetIdentifier: The asset identifier
    ///   - completion: Callback with a boolean indicating if it's a video and the video URL if applicable
    func checkIfAssetIsVideo(_ assetIdentifier: String, completion: @escaping (Bool, URL?) -> Void) {
        let allAssets = assetsByMonth.flatMap { $0.value }
        guard let asset = allAssets.first(where: { $0.localIdentifier == assetIdentifier }) else {
            completion(false, nil)
            return
        }
        
        // Check if the asset is a video
        if asset.mediaType == .video {
            // Request the video URL
            let options = PHVideoRequestOptions()
            options.version = .original
            options.deliveryMode = .highQualityFormat
            
            imageManager.requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                guard let urlAsset = avAsset as? AVURLAsset else {
                    DispatchQueue.main.async {
                        completion(false, nil)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    completion(true, urlAsset.url)
                }
            }
        } else {
            completion(false, nil)
        }
    }
}

// MARK: - Photo Bin Persistence
extension DataManager {
    /// Save photo bin asset IDs to UserDefaults
    func savePhotoBinState() {
        let assetIDs = removeStackAssets.map { $0.id }
        UserDefaults.standard.set(assetIDs, forKey: photoBinPersistenceKey)
    }
    
    /// Load photo bin assets from UserDefaults
    private func loadPhotoBinState() {
        guard let assetIDs = UserDefaults.standard.array(forKey: photoBinPersistenceKey) as? [String],
              !assetIDs.isEmpty else {
            return
        }
        
        // Clear current photo bin
        removeStackAssets.removeAll()
        
        // Find and reconstruct assets
        let allAssets = assetsByMonth.flatMap { $0.value }
        
        // Create a set of existing asset IDs for fast lookup
        let existingAssetIDs = Set(allAssets.map { $0.localIdentifier })
        
        // Filter out any saved IDs that no longer exist in the library
        let validAssetIDs = assetIDs.filter { existingAssetIDs.contains($0) }
        
        // If some assets are no longer in the library, update the saved state
        if validAssetIDs.count < assetIDs.count {
            UserDefaults.standard.set(validAssetIDs, forKey: photoBinPersistenceKey)
        }
        
        // Track which assets need to be removed from the main collections
        var assetsToRemoveFromCollections = [String]()
        
        for assetID in validAssetIDs {
            if let asset = allAssets.first(where: { $0.localIdentifier == assetID }) {
                let assetModel = AssetModel(id: asset.localIdentifier, month: asset.creationDate?.month ?? .january)
                
                // Load thumbnail
                let assetIdentifier = assetID
                let imageSize = AppConfig.sectionItemThumbnailSize
                requestImage(for: asset, assetIdentifier: assetIdentifier, size: imageSize) { image in
                    assetModel.thumbnail = image
                    if !self.removeStackAssets.contains(where: { $0.id == assetID }) {
                        self.removeStackAssets.append(assetModel)
                    }
                }
                
                // Set creation date
                assetModel.creationDate = asset.creationDate?.string(format: "MMMM dd, yyyy")
                
                // Add to the list of assets to remove from collections
                assetsToRemoveFromCollections.append(assetID)
            }
        }
        
        // Remove the assets from the main collections to ensure counts are consistent
        for assetID in assetsToRemoveFromCollections {
            if let asset = allAssets.first(where: { $0.localIdentifier == assetID }),
               let creationDate = asset.creationDate {
                let year = Calendar.current.component(.year, from: creationDate)
                let month = creationDate.month
                
                // Remove from assetsByMonth
                if var monthAssets = assetsByMonth[month] {
                    monthAssets.removeAll(where: { $0.localIdentifier == assetID })
                    assetsByMonth[month] = monthAssets
                }
                
                // Remove from assetsByYearMonth
                if var yearMonths = assetsByYearMonth[year],
                   var monthAssets = yearMonths[month] {
                    monthAssets.removeAll(where: { $0.localIdentifier == assetID })
                    yearMonths[month] = monthAssets
                    assetsByYearMonth[year] = yearMonths
                }
            }
        }
        
        // Rebuild gallery assets to ensure counts are updated
        if !assetsToRemoveFromCollections.isEmpty {
            rebuildGalleryAssets()
        }
    }
}
