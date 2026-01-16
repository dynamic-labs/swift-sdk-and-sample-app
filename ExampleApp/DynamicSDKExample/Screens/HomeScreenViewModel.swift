import Foundation
import Combine
import DynamicSDKSwift

@MainActor
final class HomeScreenViewModel: ObservableObject {
  @Published var wallets: [BaseWallet] = []
  @Published var user: UserProfile?
  @Published var token: String?
  @Published var errorMessage: String?

  private let sdk = DynamicSDK.instance()
  private var cancellables = Set<AnyCancellable>()
  private var onNavigateToLogin: (() -> Void)?

  func startListening(onNavigateToLogin: @escaping () -> Void) {
    self.onNavigateToLogin = onNavigateToLogin

    // Initial values
    wallets = sdk.wallets.userWallets
    user = sdk.auth.authenticatedUser
    token = sdk.auth.token

    // Wallet updates
    sdk.wallets.userWalletsChanges
      .receive(on: DispatchQueue.main)
      .sink { [weak self] wallets in
        self?.wallets = wallets
      }
      .store(in: &cancellables)

    // User updates (route back to login on logout)
    sdk.auth.authenticatedUserChanges
      .receive(on: DispatchQueue.main)
      .sink { [weak self] user in
        guard let self else { return }
        self.user = user
        if user == nil {
          self.wallets = []
          self.onNavigateToLogin?()
        }
      }
      .store(in: &cancellables)

    // Token updates
    sdk.auth.tokenChanges
      .receive(on: DispatchQueue.main)
      .sink { [weak self] token in
        self?.token = token
      }
      .store(in: &cancellables)
  }

  func showUserProfile() {
    sdk.ui.showUserProfile()
  }

  func logout() {
    errorMessage = nil
    Task { @MainActor in
      do {
        try await sdk.auth.logout()
        // Navigation to login is triggered by authenticatedUserChanges -> nil
      } catch {
        errorMessage = "Logout failed: \(error)"
      }
    }
  }
}


