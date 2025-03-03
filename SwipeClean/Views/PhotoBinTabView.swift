import SwiftUI
import Photos
import UIKit

/// Shows a grid of assets to be deleted
struct PhotoBinTabView: View {
    
    @EnvironmentObject var manager: DataManager
    @State public var isSelecting: Bool = true // Always in selection mode
    @State private var selectionCount: Int = 0 // Track selection count for UI updates
    private let gridSpacing: Double = 10.0
    
    // MARK: - Main rendering function
    var body: some View {
        ZStack {
            VStack {
                if manager.removeStackAssets.count == 0 {
                    EmptyDeleteAssetsList
                } else {
                    AssetsGridListView
                }
            }
            
            // Floating action buttons - show whenever there are selected assets
            if !manager.photoBinSelectedAssets.isEmpty {
                VStack {
                    Spacer()
                    
                    // Display the total size of selected assets
                    let (size, unit) = manager.calculateSelectedAssetsSize()
                    Text("\(manager.photoBinSelectedAssets.count) items selected (\(String(format: "%.1f", size)) \(unit))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondaryTextColor.opacity(0.1))
                        )
                        .padding(.bottom, 10)
                        .id("selection_size_\(selectionCount)") // Force refresh when selection changes
                    
                    HStack(spacing: 20) {
                        // Keep button
                        Button(action: {
                            keepSelectedAssets()
                        }) {
                            Label("Keep", systemImage: "heart.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(Capsule().foregroundColor(.green))
                        }
                        
                        // Delete button
                        Button(action: {
                            deleteSelectedAssets()
                        }) {
                            Label("Delete", systemImage: "trash.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(Capsule().foregroundColor(.red))
                        }
                    }
                    .padding(.bottom, 20)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                }
            }
        }
        .onAppear {
            // Set initial selection count
            selectionCount = manager.photoBinSelectedAssets.count
            
            // Add observer for selection changes
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("PhotoBinSelectionChanged"),
                object: nil,
                queue: .main
            ) { _ in
                self.selectionCount = self.manager.photoBinSelectedAssets.count
            }
        }
        .onDisappear {
            // Remove observer when view disappears
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name("PhotoBinSelectionChanged"),
                object: nil
            )
        }
    }
    
    /// Keep selected assets
    private func keepSelectedAssets() {
        // Get selected assets
        let assetsToKeep = manager.removeStackAssets.filter { manager.photoBinSelectedAssets.contains($0.id) }
        
        // Restore each selected asset
        for asset in assetsToKeep {
            manager.restoreAsset(asset)
        }
        
        // Clear selection
        manager.photoBinSelectedAssets.removeAll()
        
        // Update selection count for UI refresh
        selectionCount = 0
        
        // Force UI refresh
        DispatchQueue.main.async {
            self.manager.objectWillChange.send()
        }
    }
    
    /// Delete selected assets
    private func deleteSelectedAssets() {
        // Show confirmation alert
        let itemsCount = manager.photoBinSelectedAssets.count
        presentAlert(
            title: "Delete Photos",
            message: "Are you sure you want to permanently delete these \(itemsCount) photos?",
            primaryAction: .Cancel,
            secondaryAction: .init(title: "Delete", style: .destructive, handler: { _ in
                // Get assets to remove using the DataManager helper method
                let assetsToRemove = self.manager.getAssetsForDeletion(identifiers: self.manager.photoBinSelectedAssets)
                
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.deleteAssets(assetsToRemove as NSArray)
                } completionHandler: { success, error in
                    if success {
                        DispatchQueue.main.async {
                            // Remove the assets from the removeStackAssets array
                            self.manager.removeStackAssets.removeAll { self.manager.photoBinSelectedAssets.contains($0.id) }
                            self.manager.savePhotoBinState()
                            
                            // Clear selection
                            self.manager.photoBinSelectedAssets.removeAll()
                            
                            // Update selection count for UI refresh
                            self.selectionCount = 0
                        }
                    } else if let errorMessage = error?.localizedDescription {
                        presentAlert(title: "Oops!", message: errorMessage, primaryAction: .OK)
                    }
                }
            })
        )
    }
    
    /// Empty delete assets list
    private var EmptyDeleteAssetsList: some View {
        ZStack {
            VStack {
                LazyVGrid(columns: columns, spacing: gridSpacing) {
                    ForEach(0..<9, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 12)
                            .frame(height: tileHeight)
                            .foregroundStyle(Color.secondaryTextColor).opacity(0.2)
                    }
                }.padding(.horizontal).padding(.bottom).overlay(
                    VStack {
                        LinearGradient(colors: [.backgroundColor.opacity(0), .backgroundColor], startPoint: .top, endPoint: .bottom)
                        Spacer()
                    }
                ).opacity(0.8)
                Spacer()
            }
            
            VStack {
                Spacer()
                Image(systemName: "trash.slash")
                    .font(.system(size: 40)).padding(5)
                Text("Bin is Empty").font(.title2).fontWeight(.bold)
                Text("No photos marked for deletion. Swipe through your photos to add them here.")
                    .font(.body).multilineTextAlignment(.center).opacity(0.6)
                    .padding(.horizontal).fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
    }
    
    /// Assets grid list view
    private var AssetsGridListView: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: columns, spacing: gridSpacing) {
                ForEach(manager.removeStackAssets) { asset in
                    AssetGridItem(for: asset)
                }
            }.padding(.horizontal)
            Spacer(minLength: 20)
        }
    }
    
    /// Asset grid item
    private func AssetGridItem(for model: AssetModel) -> some View {
        let isSelected = manager.photoBinSelectedAssets.contains(model.id)
        
        return RoundedRectangle(cornerRadius: 12).frame(height: tileHeight)
            .foregroundStyle(Color.secondaryTextColor).opacity(0.2)
            .overlay(AssetImage(for: model)).clipped()
            .overlay(
                ZStack {
                    // Selection overlay
                    Rectangle()
                        .foregroundColor(.black.opacity(isSelected ? 0.3 : 0))
                        .overlay(
                            VStack {
                                HStack {
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .strokeBorder(isSelected ? Color.clear : Color.white, lineWidth: 2)
                                            .background(Circle().foregroundColor(isSelected ? .blue : .clear))
                                            .frame(width: 24, height: 24)
                                        
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(8)
                                }
                                Spacer()
                            }
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .onTapGesture {
                toggleItemSelection(assetId: model.id)
            }
    }
    
    /// Asset image preview overlay
    private func AssetImage(for model: AssetModel) -> some View {
        ZStack {
            if let thumbnail = model.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable().aspectRatio(contentMode: .fill)
            }
        }
    }
    
    /// Grid columns configuration
    private var columns: [GridItem] {
        Array(repeating: GridItem(spacing: gridSpacing), count: 3)
    }
    
    /// Grid item tile height
    private var tileHeight: Double {
        (UIScreen.main.bounds.width - 56.0)/3.0
    }
    
    /// Toggle selection of a single item
    private func toggleItemSelection(assetId: String) {
        if manager.photoBinSelectedAssets.contains(assetId) {
            manager.photoBinSelectedAssets.remove(assetId)
        } else {
            manager.photoBinSelectedAssets.insert(assetId)
        }
        
        // Update selection count for UI refresh
        selectionCount = manager.photoBinSelectedAssets.count
    }
}

// MARK: - Preview UI
#Preview {
    let manager = DataManager()
    //manager.removeStackAssets = manager.galleryAssets
    return ZStack {
        Color.backgroundColor.ignoresSafeArea()
        PhotoBinTabView().environmentObject(manager)
    }
}
