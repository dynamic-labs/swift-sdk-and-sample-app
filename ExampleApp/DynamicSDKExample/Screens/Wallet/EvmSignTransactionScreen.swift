import SwiftUI
import DynamicSDKSwift

struct EvmSignTransactionScreen: View {
  let wallet: BaseWallet
  
  @State private var toAddress: String = ""
  @State private var value: String = "0.001"
  @State private var gasLimit: String = "21000"
  @State private var maxPriorityFeePerGas: String = "2"
  @State private var maxFeePerGas: String = "50"
  @State private var signedTx: String?
  @State private var errorMessage: String?
  @State private var isLoading: Bool = false
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // Info Card
        InfoCard(
          title: "Sign EVM Transaction",
          content: "Sign an EVM transaction without sending it to the network."
        )
        
        // To Address
        TextFieldWithLabel(
          label: "To Address",
          placeholder: "0x...",
          text: $toAddress
        )
        
        // Value
        TextFieldWithLabel(
          label: "Value (ETH)",
          placeholder: "0.001",
          text: $value
        )
        
        // Gas Limit
        TextFieldWithLabel(
          label: "Gas Limit",
          placeholder: "21000",
          text: $gasLimit
        )
        
        // Max Priority Fee Per Gas
        TextFieldWithLabel(
          label: "Max Priority Fee (Gwei)",
          placeholder: "2",
          text: $maxPriorityFeePerGas
        )
        
        // Max Fee Per Gas
        TextFieldWithLabel(
          label: "Max Fee Per Gas (Gwei)",
          placeholder: "50",
          text: $maxFeePerGas
        )
        
        // Sign Button
        PrimaryButton(
          title: isLoading ? "Signing..." : "Sign Transaction",
          action: signTransaction,
          isLoading: isLoading
        )
        
        // Error Message
        if let error = errorMessage {
          ErrorMessageView(message: error)
        }
        
        // Success Message
        if let signed = signedTx {
          SuccessMessageView(
            message: signed
          )
        }
      }
      .padding()
    }
    .navigationTitle("Sign Transaction")
    .navigationBarTitleDisplayMode(.inline)
  }
  
  private func signTransaction() {
    guard !toAddress.isEmpty else {
      errorMessage = "Please enter a recipient address"
      return
    }
    
    isLoading = true
    errorMessage = nil
    signedTx = nil
    
    Task {
      do {
        let signed = try await DynamicSDK.instance().wallets.signEthereumTransaction(
          wallet: wallet,
          to: toAddress,
          value: value,
          gasLimit: gasLimit,
          maxPriorityFeePerGas: maxPriorityFeePerGas,
          maxFeePerGas: maxFeePerGas
        )
        
        await MainActor.run {
          signedTx = signed
          isLoading = false
        }
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
          isLoading = false
        }
      }
    }
  }
}

