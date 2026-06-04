import SwiftUI
import DynamicSDKSwift

struct TonSendJettonScreen: View {
  let wallet: BaseWallet

  @State private var recipientAddress: String = ""
  @State private var amount: String = "1"
  @State private var jettonMasterAddress: String = ""
  @State private var result: TonTransactionResult?
  @State private var errorMessage: String?
  @State private var isLoading: Bool = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        InfoCard(
          title: "Send Jetton",
          content: "Send Jetton tokens to a recipient address.",
          copyable: false
        )

        TextFieldWithLabel(
          label: "Recipient Address",
          placeholder: "EQ...",
          text: $recipientAddress
        )

        TextFieldWithLabel(
          label: "Jetton Master Address",
          placeholder: "EQ...",
          text: $jettonMasterAddress
        )

        TextFieldWithLabel(
          label: "Amount",
          placeholder: "1",
          text: $amount,
          keyboardType: .decimalPad
        )

        PrimaryButton(
          title: isLoading ? "Sending..." : "Send Jetton",
          action: sendJetton,
          isLoading: isLoading,
          isDisabled: !isFormValid
        )

        if let error = errorMessage {
          ErrorMessageView(message: error)
        }

        if let tx = result {
          InfoCard(title: "BOC", content: tx.boc)
          InfoCard(title: "Hash", content: tx.hash)
          SuccessMessageView(message: "Jetton sent successfully!")
        }
      }
      .padding()
    }
    .navigationTitle("Send Jetton")
    .navigationBarTitleDisplayMode(.inline)
  }

  private var isFormValid: Bool {
    let trimmedAddress = recipientAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedMaster = jettonMasterAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    let amountValue = Double(amount)
    return !trimmedAddress.isEmpty && !trimmedMaster.isEmpty && amountValue != nil && amountValue! > 0
  }

  private func sendJetton() {
    guard let walletId = wallet.id else { return }
    isLoading = true
    errorMessage = nil
    result = nil

    Task {
      do {
        let tx = try await DynamicSDK.instance().ton.sendJetton(
          walletId: walletId,
          to: recipientAddress.trimmingCharacters(in: .whitespacesAndNewlines),
          amount: amount.trimmingCharacters(in: .whitespacesAndNewlines),
          jettonMasterAddress: jettonMasterAddress.trimmingCharacters(in: .whitespacesAndNewlines)
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
