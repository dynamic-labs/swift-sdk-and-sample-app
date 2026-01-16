import SwiftUI
import DynamicSDKSwift
import BigInt

struct EvmSendTransactionScreen: View {
  let wallet: BaseWallet
  @StateObject private var viewModel: EvmSendTransactionViewModel
  @Environment(\.dismiss) private var dismiss
  
  init(wallet: BaseWallet) {
    self.wallet = wallet
    self._viewModel = StateObject(wrappedValue: EvmSendTransactionViewModel(wallet: wallet))
  }
  
  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        // Recipient Address
        TextFieldWithLabel(
          label: "Recipient Address",
          placeholder: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bDd7",
          text: $viewModel.recipientAddress
        )
        
        // Amount
        TextFieldWithLabel(
          label: "Amount (ETH)",
          placeholder: "0.001",
          text: $viewModel.amount,
          keyboardType: .decimalPad
        )
        
        // Error Message
        if let error = viewModel.errorMessage {
          ErrorMessageView(message: error)
        }
        
        // Send Button
        PrimaryButton(
          title: "Send Transaction",
          action: { Task { await viewModel.sendTransaction() } },
          isLoading: viewModel.isLoading,
          isDisabled: !viewModel.isFormValid
        )
        
        // Transaction Result
        if let txHash = viewModel.transactionHash {
          InfoCard(
            title: "Transaction Hash",
            content: txHash
          )
          
          SuccessMessageView(message: "Transaction sent successfully!")
        }
        
        Spacer()
      }
      .padding()
    }
    .navigationTitle("Send \(wallet.chain)")
    .navigationBarTitleDisplayMode(.inline)
  }
}

@MainActor
class EvmSendTransactionViewModel: ObservableObject {
  @Published var recipientAddress: String = ""
  @Published var amount: String = "0.001"
  @Published var isLoading: Bool = false
  @Published var errorMessage: String?
  @Published var transactionHash: String?
  
  private let wallet: BaseWallet
  
  var isFormValid: Bool {
    !recipientAddress.isEmpty && 
    !amount.isEmpty && 
    Double(amount) != nil &&
    recipientAddress.hasPrefix("0x")
  }
  
  init(wallet: BaseWallet) {
    self.wallet = wallet
  }
  
  func sendTransaction() async {
    guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")) else {
      errorMessage = "Invalid amount format"
      return
    }
    
    guard recipientAddress.hasPrefix("0x") else {
      errorMessage = "Invalid recipient address format"
      return
    }
    
    isLoading = true
    errorMessage = nil
    transactionHash = nil
    
    do {
      let sdk = DynamicSDK.instance()

      let chainId = await resolveChainId(sdk: sdk)
      
      // Create EVM client
      let client = sdk.evm.createPublicClient(chainId: chainId)
      
      // Get gas price
      let gasPrice = try await client.getGasPrice()
      
      // Calculate max fee per gas (2x gas price for EIP-1559)
      let maxFeePerGas = gasPrice * 2
      let maxPriorityFeePerGas = gasPrice
      
      // Convert amount to wei (1 ETH = 10^18 wei)
      let weiAmount = BigUInt(amountValue * pow(10.0, 18.0))
      
      // Create transaction
      let transaction = EthereumTransaction(
        from: wallet.address,
        to: recipientAddress,
        value: weiAmount,
        gas: BigUInt(21000), // Standard gas limit for ETH transfer
        maxFeePerGas: maxFeePerGas,
        maxPriorityFeePerGas: maxPriorityFeePerGas
      )
      
      // Send transaction
      let txHash = try await sdk.evm.sendTransaction(
        transaction: transaction,
        wallet: wallet
      )
      
      transactionHash = txHash
      Logger.info("[EVM] Transaction sent: \(txHash)")
      
    } catch {
      errorMessage = error.localizedDescription
      Logger.error("[EVM] Transaction failed: \(error)")
    }
    
    isLoading = false
  }

  private func resolveChainId(sdk: DynamicSDK) async -> Int {
    // 1) Prefer wallet's current network
    if let net = try? await sdk.wallets.getNetwork(wallet: wallet) {
      if let v = net.value.value as? Int { return v }
      if let v = net.value.value as? Double { return Int(v) }
      if let v = net.value.value as? String, let i = Int(v) { return i }
    }

    // 2) Fall back to first EVM network from store
    if let first = sdk.networks.evm.first {
      let raw = first.chainId.value
      if let v = raw as? Int { return v }
      if let v = raw as? Double { return Int(v) }
      if let v = raw as? String, let i = Int(v) { return i }
    }

    // 3) Default to Ethereum mainnet
    return 1
  }
}

#Preview {
  NavigationStack {
    EvmSendTransactionScreen(
      wallet: BaseWallet(
        address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bDd7",
        chain: "ETH"
      )
    )
  }
}

