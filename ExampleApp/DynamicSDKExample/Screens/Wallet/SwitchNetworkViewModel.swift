import Foundation
import DynamicSDKSwift

@MainActor
final class SwitchNetworkViewModel: ObservableObject {
  @Published var networks: [GenericNetwork] = []
  @Published var isLoading: Bool = true
  @Published var errorMessage: String?

  @Published var isSuccessAlertPresented: Bool = false
  @Published var successTitle: String = "Success"
  @Published var successMessage: String = "Network changed"

  private let sdk = DynamicSDK.instance()
  private let wallet: BaseWallet
  private var activeId: String?

  init(wallet: BaseWallet) {
    self.wallet = wallet
  }

  func load() async {
    isLoading = true
    errorMessage = nil
    do {
      let chain = wallet.chain.uppercased()
      networks = (chain == "EVM") ? sdk.networks.evm : sdk.networks.solana
      let current = try await sdk.wallets.getNetwork(wallet: wallet)
      activeId = normalizeAny(current.value.value)
    } catch {
      errorMessage = "Failed to load networks: \(error)"
    }
    isLoading = false
  }

  func isActive(_ network: GenericNetwork) -> Bool {
    let chain = wallet.chain.uppercased()
    let id = chain == "EVM" ? normalizeAny(network.chainId.value) : normalizeAny(network.networkId.value)
    return activeId == id
  }

  func subtitle(for network: GenericNetwork) -> String {
    let chain = wallet.chain.uppercased()
    if chain == "EVM" {
      return "chainId: \(normalizeAny(network.chainId.value))"
    }
    return "networkId: \(normalizeAny(network.networkId.value))"
  }

  func select(network: GenericNetwork) async {
    guard !isActive(network) else { return }
    do {
      let chain = wallet.chain.uppercased()
      let targetId = chain == "EVM" ? normalizeAny(network.chainId.value) : normalizeAny(network.networkId.value)
      try await sdk.wallets.switchNetwork(wallet: wallet, network: Network(network.chainId))
      activeId = targetId
      successMessage = "Switched to \(network.name)"
      isSuccessAlertPresented = true
    } catch {
      errorMessage = "Failed to switch network: \(error)"
    }
  }

  private func normalizeAny(_ value: Any) -> String {
    if let s = value as? String { return s }
    if let i = value as? Int { return String(i) }
    if let d = value as? Double { return String(Int(d)) }
    return String(describing: value)
  }
}


