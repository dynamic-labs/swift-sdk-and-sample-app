import SwiftUI
import DynamicSDKSwift

struct SuiSendTransactionScreen: View {
  let wallet: BaseWallet

  @State private var recipientAddress: String = ""
  @State private var amount: String = "0.001"
  @State private var rawTransaction: String = ""
  @State private var useRawTransaction: Bool = false
  @State private var digest: String?
  @State private var errorMessage: String?
  @State private var isLoading: Bool = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // Raw Transaction Toggle
        Toggle("Raw Transaction", isOn: $useRawTransaction)
          .onChange(of: useRawTransaction) { _ in
            digest = nil
            errorMessage = nil
          }

        if useRawTransaction {
          TextFieldWithLabel(
            label: "Transaction (base64)",
            placeholder: "Base64 encoded transaction",
            text: $rawTransaction
          )
        } else {
          TextFieldWithLabel(
            label: "Recipient Address",
            placeholder: "0x...",
            text: $recipientAddress
          )

          TextFieldWithLabel(
            label: "Amount (SUI)",
            placeholder: "0.001",
            text: $amount,
            keyboardType: .decimalPad
          )
        }

        PrimaryButton(
          title: isLoading ? "Sending..." : "Sign & Send",
          action: sendTransaction,
          isLoading: isLoading,
          isDisabled: !isFormValid
        )

        if let error = errorMessage {
          ErrorMessageView(message: error)
        }

        if let d = digest {
          InfoCard(
            title: "Transaction Digest",
            content: d
          )
          SuccessMessageView(message: "Transaction sent successfully!")
        }
      }
      .padding()
    }
    .navigationTitle("SUI Send Transaction")
    .navigationBarTitleDisplayMode(.inline)
  }

  private var isFormValid: Bool {
    if useRawTransaction {
      return !rawTransaction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    } else {
      let trimmedAddress = recipientAddress.trimmingCharacters(in: .whitespacesAndNewlines)
      let amountValue = Double(amount)
      return !trimmedAddress.isEmpty && amountValue != nil && amountValue! > 0
    }
  }

  private func sendTransaction() {
    guard let walletId = wallet.id else { return }
    isLoading = true
    errorMessage = nil
    digest = nil

    Task {
      do {
        let result: String
        if useRawTransaction {
          result = try await DynamicSDK.instance().sui.signAndSendTransaction(
            walletId: walletId,
            transaction: rawTransaction.trimmingCharacters(in: .whitespacesAndNewlines)
          )
        } else {
          result = try await DynamicSDK.instance().sui.signAndSendTransferTransaction(
            walletId: walletId,
            to: recipientAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            value: amount.trimmingCharacters(in: .whitespacesAndNewlines)
          )
        }

        await MainActor.run {
          digest = result
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
