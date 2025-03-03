import SwiftUI

/// Main dashboard for the app
struct DashboardContentView: View {
    
    @EnvironmentObject var manager: DataManager
    
    // MARK: - Main rendering function
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            TabView(selection: $manager.selectedTab) {
                ForEach(CustomTabBarItem.allCases) { tab in
                    TabBarItemFlow(type: tab)
                }
            }
            
            /// Show image processing overlay
            if manager.didProcessAssets == false {
                OverlayLoadingView()
            }
        }
        /// Full screen flow presentation
        .fullScreenCover(item: $manager.fullScreenMode) { type in
            switch type {
            case .premium: PremiumView
            }
        }
        .onAppear {
            // Check for date changes when the dashboard appears
            manager.checkAndResetDailySwipes()
        }
    }
    
    /// Custom header view
    private var CustomHeaderView: some View {
        VStack {
            HStack {
                Text(manager.selectedTab.rawValue)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(.accentColor)
                Spacer()
                
                // Add Select All/Deselect All button only for PhotoBin tab and when there are items
                if manager.selectedTab == .photoBin && manager.removeStackAssets.count > 0 {
                    Button(action: {
                        manager.togglePhotoBinSelection()
                    }) {
                        Text(manager.isAllPhotoBinItemsSelected ? "Deselect All" : "Select All")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                } else {
                    // Show free swipes count for all other tabs
                    HStack(spacing: 4) {
                        Text("\(AppConfig.freePhotosStackCount - manager.freePhotosStackCount)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.accentColor)
                            .onAppear {
                                // Check for date changes when the count is displayed
                                manager.checkAndResetDailySwipes()
                            }
                        
                        Text("/ \(AppConfig.freePhotosStackCount)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "photo.stack")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                    }
                    .id("swipeCount_\(manager.lastResetDate)_\(manager.freePhotosStackCount)") // Force refresh when date or count changes
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondaryTextColor.opacity(0.1))
                    )
                }
            }.padding()
            Spacer()
        }
    }
    
    /// Custom tab bar item flow
    private func TabBarItemFlow(type: CustomTabBarItem) -> some View {
        ZStack {
            CustomHeaderView
            let topPadding: Double = 65.0
            switch type {
            case .discover: HomeTabView().padding(.top, topPadding)
            case .swipeClean: SwipeTabView().padding(.top, topPadding)
            case .photoBin: PhotoBinTabView().padding(.top, topPadding)
            case .settings: SettingsTabView().padding(.top, topPadding)
            }
        }
        .background(Color.backgroundColor)
        .environmentObject(manager).tag(type).tabItem {
            Label(type.rawValue, systemImage: type.icon)
        }
    }
    
    /// Premium flow view
    private var PremiumView: some View {
        PremiumContentView(title: "Premium Version", subtitle: "Unlock All Features", features: AppConfig.premiumFeaturesList, productIds: [AppConfig.premiumVersion]) {
            manager.fullScreenMode = nil
        } completion: { _, status, _ in
            DispatchQueue.main.async {
                if status == .success || status == .restored {
                    manager.isPremiumUser = true
                    Interstitial.shared.isPremiumUser = true
                }
                manager.fullScreenMode = nil
            }
        }
    }
}

// MARK: - Preview UI
struct DashboardContentView_Previews: PreviewProvider {
    static var previews: some View {
        let manager = DataManager()
        manager.didGrantPermissions = true
        manager.didProcessAssets = true
        return DashboardContentView().environmentObject(manager)
    }
}
