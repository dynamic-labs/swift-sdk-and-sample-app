import SwiftUI

struct AppRootView: View {
  @State private var route: Route = .splash

  var body: some View {
    NavigationStack {
      Group {
        switch route {
        case .splash:
          SplashScreenView(
            onNavigateToLogin: { route = .login },
            onNavigateToHome: { route = .home }
          )
          .navigationBarHidden(true)

        case .login:
          LoginScreenView(
            onNavigateToHome: { route = .home }
          )
          .navigationBarHidden(true)

        case .home:
          HomeScreenView(
            onNavigateToLogin: { route = .login }
          )
        }
      }
    }
  }
}


