import SwiftUI
import DynamicSDKSwift

struct BitcoinSendScreen: View {
  let wallet: BaseWallet

  @State private var recipientAddress: String = ""
  @State private var amount: String = "1000"
  @State private var txId: String?
  @State private var errorMessage: String?
  @State private var isLoading: Bool = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        InfoCard(
          title: "Send Bitcoin",
          content: "Send Bitcoin to a recipient address. Amount is in satoshis.",
          copyable: false
        )

        TextFieldWithLabel(
          label: "Recipient Address",
          placeholder: "bc1...",
          text: $recipientAddress
        )

        TextFieldWithLabel(
          label: "Amount (satoshis)",
          placeholder: "1000",
          text: $amount,
          keyboardType: .numberPad
        )

        PrimaryButton(
          title: isLoading ? "Sending..." : "Send Bitcoin",
          action: sendBitcoin,
          isLoading: isLoading,
          isDisabled: !isFormValid
        )

        if let error = errorMessage {
          ErrorMessageView(message: error)
        }

        if let id = txId {
          InfoCard(title: "Transaction ID", content: id)
          SuccessMessageView(message: "Bitcoin sent successfully!")
        }
      }
      .padding()
    }
    .navigationTitle("Send Bitcoin")
    .navigationBarTitleDisplayMode(.inline)
  }

  private var isFormValid: Bool {
    let trimmedAddress = recipientAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    let amountValue = Int(amount)
    return !trimmedAddress.isEmpty && amountValue != nil && amountValue! > 0
  }

  private func sendBitcoin() {
    guard let walletId = wallet.id else { return }
    isLoading = true
    errorMessage = nil
    txId = nil

    Task {
      do {
        let result = try await DynamicSDK.instance().bitcoin.sendBitcoin(
          walletId: walletId,
          recipientAddress: recipientAddress.trimmingCharacters(in: .whitespacesAndNewlines),
          amount: amount.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        await MainActor.run {
          txId = result
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
