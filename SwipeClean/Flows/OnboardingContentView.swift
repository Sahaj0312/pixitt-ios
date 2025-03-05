import SwiftUI
import Lottie

/// The screen that shows up when the app launches the first time
struct OnboardingContentView: View {
    
    @EnvironmentObject var manager: DataManager
    @State private var showPermissionsScreen = false
    @State private var slideOffset: CGFloat = UIScreen.main.bounds.width
    
    // MARK: - Main rendering function
    var body: some View {
        ZStack {
            // Accent color background
            Color.backgroundColor.ignoresSafeArea()
            
            // First screen
            WelcomeScreen
                .offset(x: showPermissionsScreen ? -slideOffset : 0)
                .opacity(showPermissionsScreen ? 0 : 1)
            
            // Second screen
            PermissionsScreen
                .offset(x: showPermissionsScreen ? 0 : slideOffset)
                .opacity(showPermissionsScreen ? 1 : 0)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showPermissionsScreen)
    }
    
    /// Welcome screen with Lottie animation
    private var WelcomeScreen: some View {
        GeometryReader { geometry in
            ZStack {
                // Main content
                VStack(spacing: 0) {
                    // Main text with styled "Pixitt" in backgroundColor
                    VStack(spacing: -5) {
                        Text("Ready to ")
                            .font(.system(size: 50, weight: .regular, design: .default))
                            .foregroundColor(.primaryTextColor) +
                        Text("Pixitt")
                            .font(.system(size: 50, weight: .heavy, design: .default))
                            .foregroundColor(.accentColor)
                        
                        Text("your way to a")
                            .font(.system(size: 50, weight: .regular, design: .default))
                            .foregroundColor(.primaryTextColor)
                        
                        Text("clutter-free")
                            .font(.system(size: 50, weight: .regular, design: .default))
                            .foregroundColor(.primaryTextColor)
                        
                        Text("gallery?")
                            .font(.system(size: 50, weight: .regular, design: .default))
                            .foregroundColor(.primaryTextColor)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .zIndex(2) // Ensure text stays on top
                    
                    Spacer()
                }
                
                // Lottie animation - balanced size
                LottieView(animationName: "lottie")
                    .frame(width: geometry.size.width * 1, height: geometry.size.height * 1)
                    .offset(y: geometry.size.height * 0.22)
                    .zIndex(-1) // Position behind text but above background
                
                // Bottom button with fixed position
                VStack {
                    Spacer()
                    
                    // Let's go button
                    Button {
                        // Transition to next screen
                        withAnimation {
                            showPermissionsScreen = true
                        }
                    } label: {
                        Text("Let's Go!")
                            .font(.system(size: 22, weight: .bold, design: .default))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor)
                            )
                            .foregroundColor(.backgroundColor)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
                .zIndex(3) // Ensure button stays on top
            }
        }
    }
    
    /// Permissions screen with card stack
    private var PermissionsScreen: some View {
        GeometryReader { geometry in
            ZStack {
                // Accent color background (matching first page)
                Color.backgroundColor.ignoresSafeArea()
                
                // Content
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 5) {
                        Text("Access required to")
                            .font(.system(size: 40, weight: .regular, design: .default))
                            .foregroundColor(.primaryTextColor)
                        
                        Text("use ")
                            .font(.system(size: 40, weight: .regular, design: .default))
                            .foregroundColor(.primaryTextColor) +
                        Text("Pixitt")
                            .font(.system(size: 40, weight: .heavy, design: .default))
                            .foregroundColor(.accentColor)
                    }
                    .padding(.top, 10)
             
                    
                    // Photo Library Access Card
                    HStack(spacing: 15) {
                        // Icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "photo.stack")
                                .font(.system(size: 30))
                                .foregroundColor(.accentColor)
                        }
                        
                        // Text
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Photo Library")
                                .font(.system(size: 22, weight: .semibold, design: .default))
                                .foregroundColor(.primaryTextColor)
                            
                            Text("We need this in order to help you organize your photos.")
                                .font(.system(size: 16, weight: .regular, design: .default))
                                .foregroundColor(.primaryTextColor.opacity(0.7))
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                    )
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Security message
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.primaryTextColor.opacity(0.7))
                        
                        Text("Your media stays secure, stored solely on your device.")
                            .font(.system(size: 16, weight: .regular, design: .default))
                            .foregroundColor(.primaryTextColor.opacity(0.7))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    
                    // Get Started Button
                    Button {
                        // Call manager to get started
                        manager.getStarted()
                    } label: {
                        Text("Get Started")
                            .font(.system(size: 22, weight: .bold, design: .default))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor)
                            )
                            .foregroundColor(.backgroundColor)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
            }
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
            VStack {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 40)).padding(5)
                Text("Access Needed").font(.title2).fontWeight(.bold)
                Text("To start sorting your photos, Pixitt needs access to your gallery.")
                    .font(.body).multilineTextAlignment(.center)
                    .padding(.horizontal).opacity(0.6)
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
    
    /// Verify if `Get Started` button must be enabled
    private var isGetStartedEnabled: Bool {
        let assets: [AssetModel] = manager.keepStackAssets + manager.removeStackAssets
        return AppConfig.onboardingAssets.filter { asset in
            assets.contains(where: { $0.id == asset.id })
        }.count == AppConfig.onboardingAssets.count
    }
}

/// LottieView to display animations
struct LottieView: UIViewRepresentable {
    var animationName: String
    var loopMode: LottieLoopMode = .loop
    var animationSpeed: CGFloat = 1.0
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let animationView = LottieAnimationView()
        let animation = LottieAnimation.named(animationName)
        
        animationView.animation = animation
        animationView.contentMode = .scaleAspectFill
        animationView.loopMode = loopMode
        animationView.animationSpeed = animationSpeed
        animationView.play()
        
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor),
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
}

// MARK: - Preview UI
#Preview {
    OnboardingContentView().environmentObject(DataManager())
}
