import SwiftUI

/// Main dashboard for the app
struct DashboardContentView: View {
    
    @EnvironmentObject var manager: DataManager
    @State private var showSwipeResetMessage: Bool = false
    
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
            
            // Show swipe reset message
            if showSwipeResetMessage {
                VStack {
                    Spacer()
                    Text("Your daily swipes have been reset!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(100)
                .onAppear {
                    // Auto-hide the message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showSwipeResetMessage = false
                        }
                    }
                }
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
            
            // Add observer for swipe reset notification
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("DailySwipesReset"),
                object: nil,
                queue: .main
            ) { _ in
                withAnimation {
                    showSwipeResetMessage = true
                }
            }
        }
        .onDisappear {
            // Remove observer when view disappears
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name("DailySwipesReset"),
                object: nil
            )
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
                
                // Add Select All/Deselect All button only for Archive tab and when there are items
                if manager.selectedTab == .archive && manager.removeStackAssets.count > 0 {
                    Button(action: {
                        manager.toggleArchiveSelection()
                    }) {
                        Text(manager.isAllArchiveItemsSelected ? "Deselect All" : "Select All")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                } else {
                    // Show free swipes count for all other tabs
                    HStack(spacing: 4) {
                        // Display remaining swipes (max - used)
                        let remainingSwipes = AppConfig.freePhotosStackCount - manager.freePhotosStackCount
                        Text("\(remainingSwipes)")
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
            case .archive: ArchiveTabView().padding(.top, topPadding)
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
