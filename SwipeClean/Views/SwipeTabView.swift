import SwiftUI

/// The tab to swipe left/right on photos stack
struct SwipeTabView: View {
    
    @EnvironmentObject var manager: DataManager
    
    // MARK: - Main rendering function
    var body: some View {
        VStack {
            VStack {
                ZStack {
                    EmptyStackOverlay
                    ForEach(manager.assetsSwipeStack.reversed()) { asset in
                        PhotoCardView(asset: asset)
                    }
                }.padding([.top, .horizontal], 10)
                
                // Like/dislike buttons removed
                
            }.padding(.bottom, 5).background(
                RoundedRectangle(cornerRadius: 28).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.05), radius: 8)
            ).background(CardsStackBackground).padding(.horizontal)
            
            Text(manager.swipeStackTitle).padding(8).padding(.horizontal, 8)
                .background(RoundedRectangle(cornerRadius: 10).foregroundStyle(.white))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.primaryTextColor).padding(.top, 20)
            
            Spacer()
        }
    }
    
    /// Empty stack of photo cards
    private var EmptyStackOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).frame(height: PhotoCardView.height)
                .foregroundStyle(LinearGradient(colors: [
                    .init(white: 0.94), .backgroundColor
                ], startPoint: .top, endPoint: .bottom)).background(
                    RoundedRectangle(cornerRadius: 25)
                        .foregroundStyle(LinearGradient(colors: [.red, .accentColor, .green], startPoint: .leading, endPoint: .trailing))
                        .offset(y: 20).padding().blur(radius: 20).opacity(0.3)
                )
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                Text("You've reviewed all photos. Check your delete list in the '\(CustomTabBarItem.archive.rawValue)' tab.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    /// Cards stack background
    private var CardsStackBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .padding(40).offset(y: 65).opacity(0.3)
            RoundedRectangle(cornerRadius: 28)
                .padding().offset(y: 30).opacity(0.6)
        }
        .foregroundStyle(Color.backgroundColor)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 5)
    }
    
    /// Verify it the user has any free swipes
    private var hasFreeSwipes: Bool {
        guard !manager.isPremiumUser else { return true }
        return manager.freePhotosStackCount < AppConfig.freePhotosStackCount
    }
}

// MARK: - Preview UI
#Preview {
    let manager = DataManager()
    manager.didGrantPermissions = true
    return ZStack {
        Color.backgroundColor.ignoresSafeArea()
        SwipeTabView().environmentObject(manager)
    }
}
