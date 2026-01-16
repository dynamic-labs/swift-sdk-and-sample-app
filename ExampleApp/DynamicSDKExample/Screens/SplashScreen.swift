import SwiftUI
import DynamicSDKSwift

struct SplashScreenView: View {
  let onNavigateToLogin: () -> Void
  let onNavigateToHome: () -> Void
  
  @StateObject private var vm = SplashScreenViewModel()
  @Environment(\.colorScheme) var colorScheme
  
  var body: some View {
    ZStack {
      // System background color (white in light mode, black in dark mode)
      (colorScheme == .dark ? Color.black : Color.white)
        .ignoresSafeArea()
      
      VStack(spacing: 30) {
        ProgressView()
          .scaleEffect(1.5)
        
        Text("Loading...")
          .font(.headline)
          .foregroundColor(.secondary)
      }
    }
    .onAppear {
      vm.start(
        onNavigateToLogin: onNavigateToLogin,
        onNavigateToHome: onNavigateToHome
      )
    }
  }
}
