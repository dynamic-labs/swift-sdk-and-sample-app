import Foundation
import Combine
import DynamicSDKSwift

@MainActor
final class HomeScreenViewModel: ObservableObject {
  @Published var wallets: [BaseWallet] = []
  @Published var user: UserProfile?
  @Published var token: String?
  @Published var errorMessage: String?
  @Published var isCreatingWallets: Bool = false

  private let sdk = DynamicSDK.instance()
  private var cancellables = Set<AnyCancellable>()
  private var onNavigateToLogin: (() -> Void)?
  private var walletCreationTimer: Timer?

  func startListening(onNavigateToLogin: @escaping () -> Void) {
    self.onNavigateToLogin = onNavigateToLogin

    // Initial values
    wallets = sdk.wallets.userWallets
    user = sdk.auth.authenticatedUser
    token = sdk.auth.token
    
    // Check if wallets are being created on initial load
    checkIfCreatingWallets()

    // Wallet updates
    sdk.wallets.userWalletsChanges
      .receive(on: DispatchQueue.main)
      .sink { [weak self] wallets in
        guard let self else { return }
        self.wallets = wallets
        
        // If wallets appeared, stop showing "Creating wallets"
        if !wallets.isEmpty {
          self.isCreatingWallets = false
          self.walletCreationTimer?.invalidate()
          self.walletCreationTimer = nil
        }
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
          self.isCreatingWallets = false
          self.walletCreationTimer?.invalidate()
          self.walletCreationTimer = nil
          self.onNavigateToLogin?()
        } else {
          // User just authenticated - check if wallets are being created
          self.checkIfCreatingWallets()
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
  
  private func checkIfCreatingWallets() {
    // If user is authenticated but has no wallets, show "Creating wallets" spinner
    // Give it a timeout of 10 seconds - if no wallets appear, assume they're not being created
    if user != nil && wallets.isEmpty {
      isCreatingWallets = true
      
      // Set timeout to stop showing spinner after 10 seconds
      walletCreationTimer?.invalidate()
      walletCreationTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
        Task { @MainActor in
          self?.isCreatingWallets = false
        }
      }
    } else {
      isCreatingWallets = false
      walletCreationTimer?.invalidate()
      walletCreationTimer = nil
    }
  }
}


