import SwiftUI
import DynamicSDKSwift

struct TonSignMessageScreen: View {
  let wallet: BaseWallet

  @State private var message: String = "Hello World"
  @State private var signature: String?
  @State private var errorMessage: String?
  @State private var isLoading: Bool = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        InfoCard(
          title: "TON Sign Message",
          content: "Sign a message using the TON wallet.",
          copyable: false
        )

        TextFieldWithLabel(
          label: "Message",
          placeholder: "Enter message to sign",
          text: $message
        )

        PrimaryButton(
          title: isLoading ? "Signing..." : "Sign Message",
          action: signMessage,
          isLoading: isLoading,
          isDisabled: message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )

        if let error = errorMessage {
          ErrorMessageView(message: error)
        }

        if let sig = signature {
          InfoCard(
            title: "Signature",
            content: sig
          )
          SuccessMessageView(message: "Message signed successfully!")
        }
      }
      .padding()
    }
    .navigationTitle("TON Sign Message")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func signMessage() {
    guard let walletId = wallet.id else { return }
    isLoading = true
    errorMessage = nil
    signature = nil

    Task {
      do {
        let result = try await DynamicSDK.instance().ton.signMessage(
          walletId: walletId,
          message: message.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        await MainActor.run {
          signature = result
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
