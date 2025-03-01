import SwiftUI
import Photos
import UIKit

/// Shows a grid of assets to be deleted
struct PhotoBinTabView: View {
    
    @EnvironmentObject var manager: DataManager
    @State public var selectedAssets: Set<String> = []
    @State public var isSelecting: Bool = false
    private let gridSpacing: Double = 10.0
    
    // Computed property to check if all items are selected
    public var isAllSelected: Bool {
        !manager.removeStackAssets.isEmpty && selectedAssets.count == manager.removeStackAssets.count
    }
    
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
            .onAppear {
                // Register this view instance to be accessed by the dashboard
                NotificationCenter.default.addObserver(forName: Notification.Name("TogglePhotoBinSelection"), object: nil, queue: .main) { _ in
                    self.toggleSelection()
                }
            }
            
            // Floating action buttons - show whenever there are selected assets
            if !selectedAssets.isEmpty {
                VStack {
                    Spacer()
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
    }
    
    /// Keep selected assets
    private func keepSelectedAssets() {
        // Get selected assets
        let assetsToKeep = manager.removeStackAssets.filter { selectedAssets.contains($0.id) }
        
        // Restore each selected asset
        for asset in assetsToKeep {
            manager.restoreAsset(asset)
        }
        
        // Clear selection
        selectedAssets.removeAll()
        isSelecting = false
        
        // Force UI refresh
        DispatchQueue.main.async {
            self.manager.objectWillChange.send()
        }
    }
    
    /// Delete selected assets
    private func deleteSelectedAssets() {
        // Show confirmation alert
        let itemsCount = selectedAssets.count
        presentAlert(
            title: "Delete Photos",
            message: "Are you sure you want to permanently delete these \(itemsCount) photos?",
            primaryAction: .Cancel,
            secondaryAction: .init(title: "Delete", style: .destructive, handler: { _ in
                // Get assets to remove using the DataManager helper method
                let assetsToRemove = self.manager.getAssetsForDeletion(identifiers: self.selectedAssets)
                
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.deleteAssets(assetsToRemove as NSArray)
                } completionHandler: { success, error in
                    if success {
                        DispatchQueue.main.async {
                            // Remove the assets from the removeStackAssets array
                            self.manager.removeStackAssets.removeAll { self.selectedAssets.contains($0.id) }
                            self.manager.savePhotoBinState()
                            
                            // Clear selection
                            self.selectedAssets.removeAll()
                            self.isSelecting = false
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
        let isSelected = selectedAssets.contains(model.id)
        
        return RoundedRectangle(cornerRadius: 12).frame(height: tileHeight)
            .foregroundStyle(Color.secondaryTextColor).opacity(0.2)
            .overlay(AssetImage(for: model)).clipped()
            .overlay(
                ZStack {
                    if isSelecting {
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
                    // Remove the restore button when not in selection mode
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .onTapGesture {
                if isSelecting {
                    // Toggle selection when in selection mode
                    if isSelected {
                        selectedAssets.remove(model.id)
                    } else {
                        selectedAssets.insert(model.id)
                    }
                } else {
                    // Enter selection mode
                    isSelecting = true
                }
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
    
    /// Toggle selection mode or select/deselect all
    private func toggleSelection() {
        if isSelecting {
            // Already in selection mode, toggle select all/none
            if selectedAssets.count == manager.removeStackAssets.count {
                // Deselect all
                selectedAssets.removeAll()
            } else {
                // Select all
                selectedAssets = Set(manager.removeStackAssets.map { $0.id })
            }
        } else {
            // Enter selection mode
            isSelecting = true
        }
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
