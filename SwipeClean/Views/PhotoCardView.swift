//
//  PhotoCardView.swift
//  SwipeClean
//
//  Created by Apps4World on 1/3/25.
//

import SwiftUI

/// A swipe card showing an asset
struct PhotoCardView: View {
    
    @EnvironmentObject var manager: DataManager
    @State private var cardOffset: CGFloat = 0
    @State var fromOnboardingFlow: Bool = false
    static let height: Double = UIScreen.main.bounds.width * 1.0
    let asset: AssetModel
    
    // MARK: - Main rendering function
    var body: some View {
        RoundedRectangle(cornerRadius: 20).frame(height: PhotoCardView.height)
            .foregroundStyle(LinearGradient(colors: [
                .init(white: 0.94), .init(white: 0.97)
            ], startPoint: .top, endPoint: .bottom))
            .overlay(PermissionsView().opacity(manager.didGrantPermissions ? 0 : (fromOnboardingFlow ? 0 : 1)))
            .overlay(AssetImagePreviewOverlay).overlay(KeepDeleteOverlay)
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
    }
    
    /// Asset image preview overlay
    private var AssetImagePreviewOverlay: some View {
        ZStack {
            if let image = asset.swipeStackImage, !manager.swipeStackLoadMore {
                let width: Double = UIScreen.main.bounds.width - 52.0
                Image(uiImage: image)
                    .resizable().aspectRatio(contentMode: .fill)
                    .frame(height: PhotoCardView.height).frame(width: width)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }.opacity((manager.didGrantPermissions || fromOnboardingFlow) ? 1 : 0)
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
                manager.keepAsset(asset)

            /// When user swipes left
            } else if cardOffset < -150 {
                cardOffset = -500
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
