import SwiftUI
import DynamicSDKSwift

struct SignMessageScreen: View {
  let wallet: BaseWallet
  
  @State private var message: String = "Hello from Dynamic SDK!"
  @State private var signedMessage: String?
  @State private var errorMessage: String?
  @State private var isLoading: Bool = false
  
  @Environment(\.colorScheme) var colorScheme
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // Info Card
        InfoCard(
          title: "Sign Message",
          content: "Sign a message with your wallet. This is a common way to prove ownership of a wallet address."
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
    .navigationTitle("Sign Message")
    .navigationBarTitleDisplayMode(.inline)
  }
  
  private func signMessage() {
    isLoading = true
    errorMessage = nil
    signedMessage = nil
    
    Task {
      do {
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

