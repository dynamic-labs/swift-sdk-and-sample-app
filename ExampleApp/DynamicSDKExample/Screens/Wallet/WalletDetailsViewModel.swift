import Foundation
import DynamicSDKSwift

@MainActor
final class WalletDetailsViewModel: ObservableObject {
  @Published var balance: String?
  @Published var networkDescription: String?
  @Published var isLoadingBalance: Bool = false
  @Published var isLoadingNetwork: Bool = false
  @Published var errorMessage: String?

  private let sdk = DynamicSDK.instance()
  private let wallet: BaseWallet

  init(wallet: BaseWallet) {
    self.wallet = wallet
  }

  func refresh() {
    errorMessage = nil
    isLoadingBalance = true
    isLoadingNetwork = true

    Task { @MainActor in
      // Balance
      do {
        balance = try await sdk.wallets.getBalance(wallet: wallet)
      } catch {
        Logger.debug("[WalletDetails] getBalance error: \(error)")
      }
      isLoadingBalance = false

      // Network
      do {
        let net = try await sdk.wallets.getNetwork(wallet: wallet)
        let rawId = Self.normalizeAny(net.value.value)
        networkDescription = Self.resolveNetworkDisplay(
          walletChain: wallet.chain,
          rawId: rawId,
          evmNetworks: sdk.networks.evm,
          solanaNetworks: sdk.networks.solana
        )
      } catch {
        Logger.debug("[WalletDetails] getNetwork error: \(error)")
      }
      isLoadingNetwork = false
    }
  }

  func setPrimary() {
    guard let id = wallet.id else { return }
    errorMessage = nil
    Task { @MainActor in
      do {
        try await sdk.wallets.setPrimary(walletId: id)
      } catch {
        errorMessage = "Failed to set primary wallet: \(error)"
      }
    }
  }

  private static func normalizeAny(_ value: Any) -> String {
    if let s = value as? String { return s }
    if let i = value as? Int { return String(i) }
    if let d = value as? Double { return String(Int(d)) }
    return String(describing: value)
  }

  private static func resolveNetworkDisplay(
    walletChain: String,
    rawId: String,
    evmNetworks: [GenericNetwork],
    solanaNetworks: [GenericNetwork]
  ) -> String {
    let chain = walletChain.uppercased()

    if chain == "EVM" {
      if let match = evmNetworks.first(where: { normalizeAny($0.chainId.value) == rawId }) {
        return "\(match.name) (chainId: \(normalizeAny(match.chainId.value)))"
      }
      return "chainId: \(rawId)"
    }

    if chain == "SOL" || chain == "SOLANA" {
      if let match = solanaNetworks.first(where: { normalizeAny($0.networkId.value) == rawId || normalizeAny($0.chainId.value) == rawId }) {
        return "\(match.name) (\(rawId))"
      }
      return rawId
    }

    return rawId
  }
}


