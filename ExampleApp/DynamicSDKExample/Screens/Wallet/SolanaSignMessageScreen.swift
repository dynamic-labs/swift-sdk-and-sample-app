import SwiftUI
import DynamicSDKSwift

struct SolanaSignMessageScreen: View {
  let wallet: BaseWallet
  
  @State private var message: String = "Hello from Solana!"
  @State private var signedMessage: String?
  @State private var errorMessage: String?
  @State private var isLoading: Bool = false
  
  @Environment(\.colorScheme) var colorScheme
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // Info Card
        InfoCard(
          title: "Solana Sign Message",
          content: "Sign a message using Solana's signing mechanism."
        )
        
        // Message Input
        TextFieldWithLabel(
          label: "Message",
          placeholder: "Enter message to sign",
          text: $message
        )
        
        // Sign Button
        PrimaryButton(
          title: isLoading ? "Signing..." : "Sign Message",
          action: signMessage,
          isLoading: isLoading
        )
        
        // Error Message
        if let error = errorMessage {
          ErrorMessageView(message: error)
        }
        
        // Success Message
        if let signed = signedMessage {
          SuccessMessageView(
            message: signed
          )
        }
      }
      .padding()
    }
    .navigationTitle("Solana Sign Message")
    .navigationBarTitleDisplayMode(.inline)
  }
  
  private func signMessage() {
    isLoading = true
    errorMessage = nil
    signedMessage = nil
    
    Task {
      do {
        // For Solana, we can use a different signing method if available
        // For now, using the generic signMessage
        let signed = try await DynamicSDK.instance().wallets.signMessage(
          wallet: wallet,
          message: message
        )
        
        await MainActor.run {
          signedMessage = signed
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

