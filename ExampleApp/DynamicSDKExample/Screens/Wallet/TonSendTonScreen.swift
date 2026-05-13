import SwiftUI
import DynamicSDKSwift

struct TonSendTonScreen: View {
  let wallet: BaseWallet

  @State private var recipientAddress: String = ""
  @State private var amount: String = "0.01"
  @State private var result: TonTransactionResult?
  @State private var errorMessage: String?
  @State private var isLoading: Bool = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        InfoCard(
          title: "Send TON",
          content: "Send TON to a recipient address.",
          copyable: false
        )

        TextFieldWithLabel(
          label: "Recipient Address",
          placeholder: "EQ...",
          text: $recipientAddress
        )

        TextFieldWithLabel(
          label: "Amount (TON)",
          placeholder: "0.01",
          text: $amount,
          keyboardType: .decimalPad
        )

        PrimaryButton(
          title: isLoading ? "Sending..." : "Send TON",
          action: sendTon,
          isLoading: isLoading,
          isDisabled: !isFormValid
        )

        if let error = errorMessage {
          ErrorMessageView(message: error)
        }

        if let tx = result {
          InfoCard(title: "BOC", content: tx.boc)
          InfoCard(title: "Hash", content: tx.hash)
          SuccessMessageView(message: "TON sent successfully!")
        }
      }
      .padding()
    }
    .navigationTitle("Send TON")
    .navigationBarTitleDisplayMode(.inline)
  }

  private var isFormValid: Bool {
    let trimmedAddress = recipientAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    let amountValue = Double(amount)
    return !trimmedAddress.isEmpty && amountValue != nil && amountValue! > 0
  }

  private func sendTon() {
    guard let walletId = wallet.id else { return }
    isLoading = true
    errorMessage = nil
    result = nil

    Task {
      do {
        let tx = try await DynamicSDK.instance().ton.sendTon(
          walletId: walletId,
          to: recipientAddress.trimmingCharacters(in: .whitespacesAndNewlines),
          amount: amount.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        await MainActor.run {
          result = tx
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
