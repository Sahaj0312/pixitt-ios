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
                OnThisDateSection
                ForEach(manager.sortedYears, id: \.self) { year in
                    YearSection(year: year)
                }
            }.padding(.horizontal)
            Spacer(minLength: 20)
        }
    }
    
    // MARK: - Year section with horizontally scrollable months
    private func YearSection(year: Int) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(String(year))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primaryTextColor)
            
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
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.primaryTextColor)
                        Spacer()
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(cellSize), spacing: 4), count: 2), spacing: 4) {
                        let monthAssets = manager.assetsPreview(for: month, year: year)
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
                        
                        // Fill remaining spaces with empty rectangles if less than 4 photos
                        ForEach(monthAssets.prefix(4).count..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 8)
                                .frame(width: cellSize, height: cellSize)
                                .foregroundStyle(Color.secondaryTextColor).opacity(0.1)
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
    
    // MARK: - On This Date section
    private var OnThisDateSection: some View {
        let tileHeight: Double = UIScreen.main.bounds.width - 100.0
        return RoundedRectangle(cornerRadius: 25).frame(height: tileHeight)
            .foregroundStyle(LinearGradient(colors: [
                .init(white: 0.94), .init(white: 0.97)
            ], startPoint: .top, endPoint: .bottom))
            .background(ShadowBackgroundView(height: tileHeight))
            .overlay(OnThisDateHeaderImage(height: tileHeight))
            .overlay(OnThisDateBottomOverlay)
            .overlay(PermissionsView().opacity(manager.didGrantPermissions ? 0 : 1))
    }
    
    /// On This Date header image
    private func OnThisDateHeaderImage(height: Double) -> some View {
        ZStack {
            if let image = manager.onThisDateHeaderImage {
                let width: Double = UIScreen.main.bounds.width - 32.0
                Button { manager.updateSwipeStack(onThisDate: true) } label: {
                    Image(uiImage: image)
                        .resizable().aspectRatio(contentMode: .fill)
                        .frame(height: height).frame(width: width)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                }
            }
        }.opacity(!manager.didGrantPermissions ? 0 : 1)
    }
    
    /// Custom shadow background
    private func ShadowBackgroundView(height: Double) -> some View {
        RoundedRectangle(cornerRadius: 25).offset(y: 20)
            .foregroundStyle(Color.accentColor).padding()
            .blur(radius: 10).opacity(0.5)
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
                        .font(.system(size: 15, weight: .medium))
                    Text("On This Date")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                }
                Spacer()
            }
            .foregroundStyle(Color.white)
            .padding(10).padding(.horizontal, 5).background(
                RoundedCorner(radius: 25, corners: [.bottomLeft, .bottomRight])
                    .foregroundStyle(Color.primaryTextColor).opacity(0.3)
            )
            .opacity(manager.didGrantPermissions ? 1 : 0)
        }.allowsHitTesting(false)
    }
    
    /// No photos on this date
    private var NoPhotosOverlay: some View {
        VStack {
            Image(systemName: "calendar")
                .font(.system(size: 40)).padding(5)
            Text("Empty Today").font(.title2).fontWeight(.bold)
            Text("Nothing from this date. Explore other memories or check back later.")
                .font(.body).multilineTextAlignment(.center)
                .padding(.horizontal).opacity(0.6)
        }.opacity(manager.didGrantPermissions && !manager.hasPhotosOnThisDate ? 1 : 0)
    }
}

// MARK: - Preview UI
#Preview {
    let manager = DataManager()
    manager.didGrantPermissions = true
    manager.didProcessAssets = true
    return HomeTabView().environmentObject(manager)
}
