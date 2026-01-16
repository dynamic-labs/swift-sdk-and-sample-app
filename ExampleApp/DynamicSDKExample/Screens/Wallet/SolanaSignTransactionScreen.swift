import SwiftUI
import DynamicSDKSwift

struct SolanaSignTransactionScreen: View {
  let wallet: BaseWallet
  @State private var base64Transaction = ""
  @State private var signedTransaction: String?
  @State private var isLoading = false
  @State private var errorMessage: String?
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("Sign Solana Transaction")
          .font(.title2)
          .fontWeight(.bold)
          .padding(.horizontal)
        
        // Transaction Input
        TextFieldWithLabel(
          label: "Base64 Encoded Transaction",
          placeholder: "Enter base64 transaction...",
          text: $base64Transaction
        )
        
        // Error Message
        if let error = errorMessage {
          ErrorMessageView(message: error)
        }
        
        // Sign Button
        PrimaryButton(
          title: "Sign Transaction",
          action: { signTransaction() },
          isLoading: isLoading,
          isDisabled: base64Transaction.isEmpty
        )
        
        // Signed Transaction Result
        if let signed = signedTransaction {
          InfoCard(
            title: "Signed Transaction",
            content: signed
          )
          SuccessMessageView(message: "Transaction signed successfully!")
        }
        
        Spacer()
      }
      .padding(.vertical)
    }
    .navigationTitle("Sign Transaction")
    .navigationBarTitleDisplayMode(.inline)
  }
  
  private func signTransaction() {
    isLoading = true
    errorMessage = nil
    signedTransaction = nil
    
    Task {
      do {
        let signer = DynamicSDK.instance().solana.createSigner(wallet: wallet)
        let signed = try await signer.signEncodedTransaction(base64Transaction: base64Transaction)
        signedTransaction = signed
        Logger.info("[Solana] Transaction signed: \(signed)")
      } catch {
        errorMessage = error.localizedDescription
        Logger.error("[Solana] Transaction signing failed: \(error)")
      }
      isLoading = false
    }
  }
}

