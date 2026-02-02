import Foundation
import DynamicSDKSwift
import Combine

// Predefined token model
struct PredefinedToken: Identifiable, Equatable {
  let id = UUID()
  let name: String
  let symbol: String
  let networkId: Int
  let contractAddress: String
  let networkName: String

  static func == (lhs: PredefinedToken, rhs: PredefinedToken) -> Bool {
    lhs.contractAddress == rhs.contractAddress && lhs.networkId == rhs.networkId
  }
}

// EVM tokens
let evmTokens: [PredefinedToken] = [
  PredefinedToken(
    name: "USDC Mainnet",
    symbol: "USDC",
    networkId: 1,
    contractAddress: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    networkName: "Ethereum"
  ),
  PredefinedToken(
    name: "USDC Sepolia",
    symbol: "USDC",
    networkId: 11155111,
    contractAddress: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
    networkName: "Sepolia"
  ),
  PredefinedToken(
    name: "USDC Polygon",
    symbol: "USDC",
    networkId: 137,
    contractAddress: "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359",
    networkName: "Polygon"
  ),
  PredefinedToken(
    name: "USDC Arbitrum",
    symbol: "USDC",
    networkId: 42161,
    contractAddress: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831",
    networkName: "Arbitrum"
  ),
  PredefinedToken(
    name: "USDC Base",
    symbol: "USDC",
    networkId: 8453,
    contractAddress: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    networkName: "Base"
  )
]

// Solana tokens
let solanaTokens: [PredefinedToken] = [
  PredefinedToken(
    name: "USDC Mainnet",
    symbol: "USDC",
    networkId: 101,
    contractAddress: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
    networkName: "Solana Mainnet"
  ),
  PredefinedToken(
    name: "USDC Devnet",
    symbol: "USDC",
    networkId: 103,
    contractAddress: "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU",
    networkName: "Solana Devnet"
  )
]

@MainActor
class CustomBalanceViewModel: ObservableObject {
  private let wallet: BaseWallet

  @Published var contractAddress: String = ""
  @Published var networkId: String = ""
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var result: TokenBalance?
  @Published var hasChecked = false

  var isSolanaWallet: Bool {
    let chain = wallet.chain.uppercased()
    return chain == "SOL" || chain == "SOLANA"
  }

  var predefinedTokens: [PredefinedToken] {
    isSolanaWallet ? solanaTokens : evmTokens
  }

  var chain: ChainEnum {
    isSolanaWallet ? .sol : .evm
  }

  init(wallet: BaseWallet) {
    self.wallet = wallet
  }

  func selectToken(_ token: PredefinedToken) {
    contractAddress = token.contractAddress
    networkId = String(token.networkId)
    result = nil
    errorMessage = nil
    hasChecked = false
  }

  func isTokenSelected(_ token: PredefinedToken) -> Bool {
    contractAddress == token.contractAddress && networkId == String(token.networkId)
  }

  func onInputChanged() {
    if hasChecked || result != nil {
      hasChecked = false
      result = nil
    }
  }

  func checkBalance() {
    let contract = contractAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    let networkIdStr = networkId.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !contract.isEmpty else {
      errorMessage = "Please enter a contract address"
      return
    }

    guard let networkIdInt = Int(networkIdStr) else {
      errorMessage = "Please enter a valid network ID"
      return
    }

    isLoading = true
    errorMessage = nil
    result = nil

    Task {
      do {
        guard let sdk = DynamicSDK.shared else {
          throw NSError(domain: "CustomBalanceVM", code: 1, userInfo: [NSLocalizedDescriptionKey: "SDK not initialized"])
        }

        let request = MultichainBalanceRequest(
          balanceRequests: [
            BalanceRequestItem(
              address: wallet.address,
              chain: chain,
              networkIds: [networkIdInt],
              whitelistedContracts: [contract]
            )
          ],
          filterSpamTokens: false
        )

        let response = try await sdk.wallets.getMultichainBalances(balanceRequest: request)

        // Find the token matching our contract address
        let token = response.balances.first { balance in
          balance.contractAddress?.lowercased() == contract.lowercased()
        }

        result = token
        hasChecked = true

      } catch {
        errorMessage = "Failed to fetch balance: \(error.localizedDescription)"
      }

      isLoading = false
    }
  }
}
