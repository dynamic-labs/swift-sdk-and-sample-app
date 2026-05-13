import SwiftUI
import DynamicSDKSwift

struct BitcoinSignPsbtScreen: View {
  let wallet: BaseWallet

  @State private var psbtBase64: String = ""
  @State private var signedPsbt: String?
  @State private var errorMessage: String?
  @State private var isLoading: Bool = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        InfoCard(
          title: "Sign PSBT",
          content: "Sign a Partially Signed Bitcoin Transaction (PSBT) in base64 format.",
          copyable: false
        )

        TextFieldWithLabel(
          label: "Unsigned PSBT (base64)",
          placeholder: "Paste base64-encoded PSBT",
          text: $psbtBase64
        )

        PrimaryButton(
          title: isLoading ? "Signing..." : "Sign PSBT",
          action: signPsbt,
          isLoading: isLoading,
          isDisabled: psbtBase64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )

        if let error = errorMessage {
          ErrorMessageView(message: error)
        }

        if let signed = signedPsbt {
          InfoCard(title: "Signed PSBT", content: signed)
          SuccessMessageView(message: "PSBT signed successfully!")
        }
      }
      .padding()
    }
    .navigationTitle("Sign PSBT")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func signPsbt() {
    guard let walletId = wallet.id else { return }
    isLoading = true
    errorMessage = nil
    signedPsbt = nil

    Task {
      do {
        let result = try await DynamicSDK.instance().bitcoin.signPsbt(
          walletId: walletId,
          request: [
            "unsignedPsbtBase64": psbtBase64.trimmingCharacters(in: .whitespacesAndNewlines)
          ]
        )

        await MainActor.run {
          signedPsbt = result
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
