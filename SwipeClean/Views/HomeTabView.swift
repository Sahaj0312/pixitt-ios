import SwiftUI
import Photos

/// The main home tab to show photo gallery sections
struct HomeTabView: View {
    
    @EnvironmentObject var manager: DataManager
    private let gridSpacing: Double = 10.0
    
    // MARK: - Main rendering function
    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 35) {
                // Side-by-side collections
                TopCollectionsRow
                
                ForEach(manager.sortedYears, id: \.self) { year in
                    YearSection(year: year)
                }
            }.padding(.horizontal)
            Spacer(minLength: 20)
        }
    }
    
    // MARK: - Top collections row (On This Date and Videos side by side)
    private var TopCollectionsRow: some View {
        HStack(spacing: 15) {
            OnThisDateCard
            VideosCard
        }
    }
    
    // MARK: - Year section with horizontally scrollable months
    private func YearSection(year: Int) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(String(year))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.accentColor)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 15) {
                    ForEach(manager.sortedMonths(for: year), id: \.self) { month in
                        MonthPreview(month: month, year: year)
                    }
                }
            }
        }
    }
    
    // MARK: - Month preview section
    private func MonthPreview(month: CalendarMonth, year: Int) -> some View {
        Button { manager.updateSwipeStack(with: month, year: year) } label: {
            VStack(spacing: 8) {
                let tileWidth: Double = (UIScreen.main.bounds.width - 200.0)
                let gridWidth = tileWidth - 16
                let cellSize = (gridWidth - 4) / 2
                
                VStack(spacing: 6) {
                    HStack {
                        Text(month.rawValue.capitalized)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primaryTextColor)
                        Spacer()
                    }
                    
                    let monthAssets = manager.assetsPreview(for: month, year: year)
                    if monthAssets.count == 1, let asset = monthAssets.first {
                        // Single image view
                        RoundedRectangle(cornerRadius: 8)
                            .frame(width: gridWidth, height: gridWidth)
                            .foregroundStyle(Color.secondaryTextColor).opacity(0.2)
                            .overlay(
                                Group {
                                    if let thumbnail = asset.thumbnail {
                                        Image(uiImage: thumbnail)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: gridWidth, height: gridWidth)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        // 2x2 grid view
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(cellSize), spacing: 4), count: 2), spacing: 4) {
                            ForEach(Array(monthAssets.prefix(4).enumerated()), id: \.element.id) { index, asset in
                                RoundedRectangle(cornerRadius: 8)
                                    .frame(width: cellSize, height: cellSize)
                                    .foregroundStyle(Color.secondaryTextColor).opacity(0.2)
                                    .overlay(
                                        Group {
                                            if let thumbnail = asset.thumbnail {
                                                Image(uiImage: thumbnail)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: cellSize, height: cellSize)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                        }
                                    )
                                    .overlay(
                                        Group {
                                            if index == 3, let totalCount = manager.assetsByYearMonth[year]?[month]?.count, totalCount > 4 {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .foregroundStyle(Color.primaryTextColor.opacity(0.7))
                                                    .overlay(
                                                        Text("+\(totalCount - 3)")
                                                            .foregroundStyle(.white)
                                                            .font(.system(size: 14, weight: .semibold))
                                                    )
                                            }
                                        }
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            // Fill remaining spaces with empty rectangles if less than 4 photos but more than 1
                            if monthAssets.count > 1 {
                                ForEach(monthAssets.prefix(4).count..<4, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 8)
                                        .frame(width: cellSize, height: cellSize)
                                        .foregroundStyle(Color.secondaryTextColor).opacity(0.1)
                                }
                            }
                        }
                    }
                }
                .frame(width: tileWidth)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .foregroundStyle(Color.secondaryTextColor.opacity(0.1))
                )
            }
        }
    }
    
    // MARK: - Asset preview image
    private func AssetPreviewImage(for asset: PHAsset, month: CalendarMonth) -> some View {
        let assetModel = AssetModel(id: asset.localIdentifier, month: month)
        let assetIdentifier = asset.localIdentifier + "_thumbnail"
        let imageSize = AppConfig.sectionItemThumbnailSize
        
        return GeometryReader { geometry in
            ZStack {
                Color.clear
                if let thumbnail = assetModel.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    Color.clear.onAppear {
                        _ = manager.requestImage(for: asset, assetIdentifier: assetIdentifier, size: imageSize) { image in
                            assetModel.thumbnail = image
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Photo count overlay
    private func PhotoCountOverlay(count: Int) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("\(count) photos")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundStyle(Color.primaryTextColor.opacity(0.7))
                    )
                    .padding(10)
            }
        }
    }
    
    // MARK: - On This Date card
    private var OnThisDateCard: some View {
        let cardWidth = (UIScreen.main.bounds.width - 45) / 2 // Account for padding and spacing
        let cardHeight = cardWidth * 1.3
        
        return RoundedRectangle(cornerRadius: 25)
            .frame(width: cardWidth, height: cardHeight)
            .foregroundStyle(LinearGradient(colors: [
                .init(white: 0.94), .init(white: 0.97)
            ], startPoint: .top, endPoint: .bottom))
            .background(CardShadowBackground(width: cardWidth, height: cardHeight))
            .overlay(OnThisDateHeaderImage(width: cardWidth, height: cardHeight))
            .overlay(OnThisDateBottomOverlay)
            .overlay(PermissionsView().opacity(manager.didGrantPermissions ? 0 : 1))
    }
    
    // MARK: - Videos card
    private var VideosCard: some View {
        let cardWidth = (UIScreen.main.bounds.width - 45) / 2 // Account for padding and spacing
        let cardHeight = cardWidth * 1.3
        
        return RoundedRectangle(cornerRadius: 25)
            .frame(width: cardWidth, height: cardHeight)
            .foregroundStyle(LinearGradient(colors: [
                .init(white: 0.94), .init(white: 0.97)
            ], startPoint: .top, endPoint: .bottom))
            .background(CardShadowBackground(width: cardWidth, height: cardHeight))
            .overlay(VideosHeaderImage(width: cardWidth, height: cardHeight))
            .overlay(VideosBottomOverlay)
            .overlay(PermissionsView().opacity(manager.didGrantPermissions ? 0 : 1))
    }
    
    /// On This Date header image
    private func OnThisDateHeaderImage(width: Double, height: Double) -> some View {
        ZStack {
            if let image = manager.onThisDateHeaderImage {
                Button { manager.updateSwipeStack(onThisDate: true) } label: {
                    Image(uiImage: image)
                        .resizable().aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                }
            }
        }.opacity(!manager.didGrantPermissions ? 0 : 1)
    }
    
    /// Videos header image
    private func VideosHeaderImage(width: Double, height: Double) -> some View {
        ZStack {
            if let image = manager.videosHeaderImage {
                Button { manager.updateSwipeStack(videos: true) } label: {
                    Image(uiImage: image)
                        .resizable().aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                        .overlay(
                            // Video play icon overlay
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                        )
                }
            }
        }.opacity(!manager.didGrantPermissions || !manager.hasVideos ? 0 : 1)
    }
    
    /// Custom shadow background for cards
    private func CardShadowBackground(width: Double, height: Double) -> some View {
        RoundedRectangle(cornerRadius: 25).offset(y: 10)
            .frame(width: width, height: height)
            .foregroundStyle(Color.accentColor).padding(5)
            .blur(radius: 8).opacity(0.4)
    }
    
    /// On This Date bottom overlay
    private var OnThisDateBottomOverlay: some View {
        VStack {
            Spacer()
            NoPhotosOverlay
            Spacer()
            HStack {
                VStack(alignment: .leading) {
                    Text(Date().string(format: "MMMM d"))
                        .font(.system(size: 12, weight: .medium))
                    Text("On This Date")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                Spacer()
            }
            .foregroundStyle(Color.white)
            .padding(8).padding(.horizontal, 4).background(
                RoundedCorner(radius: 25, corners: [.bottomLeft, .bottomRight])
                    .foregroundStyle(Color.primaryTextColor).opacity(0.3)
            )
            .opacity(manager.didGrantPermissions ? 1 : 0)
        }.allowsHitTesting(false)
    }
    
    /// Videos bottom overlay
    private var VideosBottomOverlay: some View {
        VStack {
            Spacer()
            NoVideosOverlay
            Spacer()
            HStack {
                VStack(alignment: .leading) {
                    Text("\(manager.videoAssets.count) Videos")
                        .font(.system(size: 12, weight: .medium))
                        .id("videoCount_\(manager.videoAssets.count)") // Force refresh when count changes
                    Text("Videos")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                Spacer()
            }
            .foregroundStyle(Color.white)
            .padding(8).padding(.horizontal, 4).background(
                RoundedCorner(radius: 25, corners: [.bottomLeft, .bottomRight])
                    .foregroundStyle(Color.primaryTextColor).opacity(0.3)
            )
            .opacity(manager.didGrantPermissions && manager.hasVideos ? 1 : 0)
        }.allowsHitTesting(false)
    }
    
    /// No photos on this date
    private var NoPhotosOverlay: some View {
        VStack {
            Image(systemName: "calendar")
                .font(.system(size: 30)).padding(3)
            Text("Empty Today").font(.headline).fontWeight(.bold)
            Text("Nothing from this date.")
                .font(.caption).multilineTextAlignment(.center)
                .padding(.horizontal, 5).opacity(0.6)
        }
        .padding(.horizontal, 5)
        .opacity(manager.didGrantPermissions && !manager.hasPhotosOnThisDate ? 1 : 0)
    }
    
    /// No videos overlay
    private var NoVideosOverlay: some View {
        VStack {
            Image(systemName: "video")
                .font(.system(size: 30)).padding(3)
            Text("No Videos").font(.headline).fontWeight(.bold)
            Text("No videos found.")
                .font(.caption).multilineTextAlignment(.center)
                .padding(.horizontal, 5).opacity(0.6)
        }
        .padding(.horizontal, 5)
        .opacity(manager.didGrantPermissions && !manager.hasVideos ? 1 : 0)
    }
}

// MARK: - Preview UI
#Preview {
    let manager = DataManager()
    manager.didGrantPermissions = true
    manager.didProcessAssets = true
    return HomeTabView().environmentObject(manager)
}
