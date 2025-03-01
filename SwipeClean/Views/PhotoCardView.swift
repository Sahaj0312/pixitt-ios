import SwiftUI
import AVKit

/// A swipe card showing an asset
struct PhotoCardView: View {
    
    @EnvironmentObject var manager: DataManager
    @State private var cardOffset: CGFloat = 0
    @State var fromOnboardingFlow: Bool = false
    @State private var videoPlayer: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var isTopCard: Bool = false
    @State private var isVideo: Bool = false
    
    static let height: Double = UIScreen.main.bounds.width * 1.0
    let asset: AssetModel
    
    // MARK: - Main rendering function
    var body: some View {
        RoundedRectangle(cornerRadius: 20).frame(height: PhotoCardView.height)
            .foregroundStyle(LinearGradient(colors: [
                .init(white: 0.94), .init(white: 0.97)
            ], startPoint: .top, endPoint: .bottom))
            .overlay(PermissionsView().opacity(manager.didGrantPermissions ? 0 : (fromOnboardingFlow ? 0 : 1)))
            .overlay(AssetMediaPreviewOverlay).overlay(KeepDeleteOverlay)
            .overlay(AssetCreationDateTag).overlay(LoadingMoreOverlay)
            .offset(x: cardOffset)
            .rotationEffect(.init(degrees: cardOffset == 0 ? 0 : (cardOffset > 0 ? 12 : -12)))
            .gesture(
                DragGesture().onChanged { value in
                    guard isSwipingEnabled else { return }
                    withAnimation(.default) {
                        cardOffset = value.translation.width
                    }
                }.onEnded { value in
                    guard isSwipingEnabled else { return }
                    updateCardEndPosition()
                }
            )
            .disabled(!hasFreeSwipes)
            .onAppear {
                checkIfTopCard()
            }
            .onChange(of: manager.assetsSwipeStack.count) { _ in
                checkIfTopCard()
            }
            .onDisappear {
                stopVideo()
            }
    }
    
    /// Check if this card is the top-most card and manage video playback
    private func checkIfTopCard() {
        guard !manager.assetsSwipeStack.isEmpty else { return }
        let isNowTopCard = manager.assetsSwipeStack.first?.id == asset.id
        
        if isNowTopCard && !isTopCard {
            // This card just became the top card
            isTopCard = true
            loadVideoIfNeeded()
        } else if !isNowTopCard && isTopCard {
            // This card is no longer the top card
            isTopCard = false
            stopVideo()
        }
    }
    
    /// Load and play video if the asset is a video
    private func loadVideoIfNeeded() {
        guard let assetId = asset.id.isEmpty ? nil : asset.id else { return }
        
        // Check if the asset is a video by asking the DataManager
        manager.checkIfAssetIsVideo(assetId) { isVideo, videoURL in
            DispatchQueue.main.async {
                self.isVideo = isVideo
            }
            
            guard isVideo, let url = videoURL else { return }
            
            DispatchQueue.main.async {
                // Create and configure video player
                self.videoPlayer = AVPlayer(url: url)
                
                // Start playing
                self.videoPlayer?.play()
                self.isPlaying = true
                
                // Loop the video when it ends
                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, 
                                                      object: self.videoPlayer?.currentItem, 
                                                      queue: .main) { _ in
                    self.videoPlayer?.seek(to: CMTime.zero)
                    self.videoPlayer?.play()
                }
            }
        }
    }
    
    /// Stop video playback
    private func stopVideo() {
        videoPlayer?.pause()
        isPlaying = false
        videoPlayer = nil
    }
    
    /// Asset media preview overlay (handles both image and video)
    private var AssetMediaPreviewOverlay: some View {
        ZStack {
            if let image = asset.swipeStackImage, !manager.swipeStackLoadMore {
                let width: Double = UIScreen.main.bounds.width - 52.0
                
                if isPlaying, let player = videoPlayer {
                    // Video player when the asset is a video
                    VideoPlayer(player: player)
                        .frame(height: PhotoCardView.height)
                        .frame(width: width)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .onTapGesture {
                            toggleVideoPlayback()
                        }
                } else {
                    // Image when the asset is a photo or video not yet playing
                    Image(uiImage: image)
                        .resizable().aspectRatio(contentMode: .fill)
                        .frame(height: PhotoCardView.height).frame(width: width)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            ZStack {
                                if isVideo && (videoPlayer != nil || isTopCard) {
                                    VStack {
                                        HStack {
                                            Spacer()
                                            // Video indicator
                                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                                .font(.system(size: 30))
                                                .foregroundStyle(.white)
                                                .shadow(radius: 2)
                                                .padding(12)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        )
                        .onTapGesture {
                            toggleVideoPlayback()
                        }
                }
            }
        }.opacity((manager.didGrantPermissions || fromOnboardingFlow) ? 1 : 0)
    }
    
    /// Toggle video playback state
    private func toggleVideoPlayback() {
        guard let player = videoPlayer else {
            // If video player hasn't been created yet but this is a video,
            // load it now
            if isTopCard {
                loadVideoIfNeeded()
            }
            return
        }
        
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }
    
    /// Asset creation date tag
    private var AssetCreationDateTag: some View {
        VStack {
            Spacer()
            if let date = asset.creationDate {
                Text(date).padding(8).padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .foregroundStyle(.white).opacity(0.8)
                    )
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.primaryTextColor).padding(.top, 38)
            }
        }.padding()
    }
    
    /// Loading more assets to the stack
    private var LoadingMoreOverlay: some View {
        ZStack {
            if manager.swipeStackLoadMore {
                OverlayLoadingView(subtitle: "Loading more for '\(manager.swipeStackTitle)'")
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
    }
    
    /// Keep/Delete overlay
    private var KeepDeleteOverlay: some View {
        func overlay(text: String, color: Color) -> some View {
            Text(text).font(.system(size: 25, weight: .semibold, design: .rounded))
                .padding(8).padding(.horizontal, 10).background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14).opacity(0.7)
                        RoundedRectangle(cornerRadius: 14).stroke(lineWidth: 4)
                    }.foregroundStyle(color)
                ).foregroundStyle(.white)
        }
        return VStack {
            HStack {
                overlay(text: "KEEP", color: .green)
                    .opacity(cardOffset > 30 ? 1 : 0)
                Spacer()
                overlay(text: "DELETE", color: .red)
                    .opacity(cardOffset < -30 ? 1 : 0)
            }.padding()
            Spacer()
        }
    }
    
    /// Update card position after the user lifts the finger off the screen
    private func updateCardEndPosition() {
        withAnimation(.easeIn){
            /// When user swipes right
            if cardOffset > 150 {
                cardOffset = 500
                stopVideo()
                manager.keepAsset(asset)

            /// When user swipes left
            } else if cardOffset < -150 {
                cardOffset = -500
                stopVideo()
                manager.deleteAsset(asset)
            } else {
                cardOffset = 0
            }
        }
    }
    
    /// Verify if the card can be swiped
    private var isSwipingEnabled: Bool {
        fromOnboardingFlow || (manager.didGrantPermissions && manager.assetsSwipeStack.count > 0 && !manager.swipeStackLoadMore)
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
    return PhotoCardView(fromOnboardingFlow: true, asset: .init(id: "", month: .may))
        .padding().environmentObject(manager)
}
