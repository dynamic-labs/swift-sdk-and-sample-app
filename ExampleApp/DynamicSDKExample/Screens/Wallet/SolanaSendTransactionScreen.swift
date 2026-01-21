import SwiftUI
import DynamicSDKSwift
import SolanaWeb3

struct SolanaSendTransactionScreen: View {
  let wallet: BaseWallet
  @StateObject private var viewModel: SolanaSendTransactionViewModel
  @Environment(\.dismiss) private var dismiss
  
  init(wallet: BaseWallet) {
    self.wallet = wallet
    self._viewModel = StateObject(wrappedValue: SolanaSendTransactionViewModel(wallet: wallet))
  }
  
  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        // Recipient Address
        TextFieldWithLabel(
          label: "Recipient Address",
          placeholder: "4ybGGu1vxysaZrBBSLVGfsxLydHREkHDYHUCnFk6os5D",
          text: $viewModel.recipientAddress
        )
        
        // Amount
        TextFieldWithLabel(
          label: "Amount (SOL)",
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
            title: "Transaction Signature",
            content: txHash
          )
          
          SuccessMessageView(message: "Transaction sent successfully!")
        }
        
        Spacer()
      }
      .padding()
    }
    .navigationTitle("Send SOL")
    .navigationBarTitleDisplayMode(.inline)
  }
}

@MainActor
class SolanaSendTransactionViewModel: ObservableObject {
  @Published var recipientAddress: String = ""
  @Published var amount: String = "0.001"
  @Published var isLoading: Bool = false
  @Published var errorMessage: String?
  @Published var transactionHash: String?
  
  private let wallet: BaseWallet
  
  var isFormValid: Bool {
    !recipientAddress.isEmpty && !amount.isEmpty && Double(amount) != nil
  }
  
  init(wallet: BaseWallet) {
    self.wallet = wallet
  }
  
  func sendTransaction() async {
    guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")) else {
      errorMessage = "Invalid amount format"
      return
    }
    
    isLoading = true
    errorMessage = nil
    transactionHash = nil
    
    do {
      let sdk = DynamicSDK.instance()
      
      // Convert SOL to lamports (1 SOL = 1,000,000,000 lamports)
      let lamports = UInt64(amountValue * 1_000_000_000)
      
      // Create signer and connection (prefer SDK-configured network)
      let signer = sdk.solana.createSigner(wallet: wallet)
      let connection = try sdk.solana.createConnection()
      
      // Get latest blockhash
      let blockhash = try await connection.getLatestBlockhash()
        
    
        let transaction = try SolanaWeb3.SolanaTransactionBuilder.createVersionedTransferTransaction(
        from: wallet.address,
        to: recipientAddress,
        lamports: lamports,
        recentBlockhash: blockhash.blockhash
      )
      
      
      // Sign and send transaction
        let signature = try await signer.signAndSendEncodedTransaction(base64Transaction: transaction.serializeToBase64())
      
      transactionHash = signature
      Logger.info("[Solana] Transaction sent: \(signature)")
      
    } catch {
      errorMessage = error.localizedDescription
      Logger.error("[Solana] Transaction failed: \(error)")
    }
    
    isLoading = false
  }
}

#Preview {
  NavigationStack {
    SolanaSendTransactionScreen(
      wallet: BaseWallet(
        id: "test-id",
        address: "7vCmPXwLpVqKHcJVr3pqQAkc2EB6D4Q93fQzXYJXJcKp",
        chain: "SOL"
      )
    )
  }
}

