import Foundation
import DynamicSDKSwift

@MainActor
final class SplashScreenViewModel: ObservableObject {
  private let sdk = DynamicSDK.instance()
  private var didRoute = false

  func start(
    onNavigateToLogin: @escaping () -> Void,
    onNavigateToHome: @escaping () -> Void
  ) {
    guard !didRoute else { return }

   
    // We also wait a bit longer for SDK/webview hydration (token/user might arrive async).
    let minSplashNs: UInt64 = 650_000_000  // 0.65s (prevents flash)
    let maxWaitNs: UInt64 = 3_000_000_000  // 3s timeout (then default to login)
    let pollNs: UInt64 = 150_000_000       // 0.15s polling interval

    Task { @MainActor in
      let start = DispatchTime.now().uptimeNanoseconds

      // Wait until we have auth info (user or token), or we time out.
      while (DispatchTime.now().uptimeNanoseconds - start) < maxWaitNs {
        if sdk.auth.authenticatedUser != nil || sdk.auth.token != nil {
          break
        }
        try? await Task.sleep(nanoseconds: pollNs)
      }

      // Ensure splash is visible at least minSplashNs
      let elapsed = DispatchTime.now().uptimeNanoseconds - start
      if elapsed < minSplashNs {
        try? await Task.sleep(nanoseconds: minSplashNs - elapsed)
      }

      guard !didRoute else { return }
      didRoute = true

      if sdk.auth.authenticatedUser != nil || sdk.auth.token != nil {
        onNavigateToHome()
      } else {
        onNavigateToLogin()
      }
    }
  }
}


