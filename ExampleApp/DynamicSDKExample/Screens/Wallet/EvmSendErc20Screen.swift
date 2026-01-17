import SwiftUI
import DynamicSDKSwift
import SwiftBigInt

struct EvmSendErc20Screen: View {
  let wallet: BaseWallet

  @State private var tokenAddress: String = ""
  @State private var recipient: String = ""
  @State private var amount: String = ""
  @State private var decimals: String = "18"

  @State private var txHash: String?
  @State private var errorMessage: String?
  @State private var isLoading: Bool = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        InfoCard(
          title: "Send ERC20",
          content: "Calls ERC20 transfer(recipient, amount) via evm.writeContract using Erc20.abi."
        )

        TextFieldWithLabel(
          label: "Token Contract Address",
          placeholder: "0x...",
          text: $tokenAddress
        )

        TextFieldWithLabel(
            
          label: "Recipient",
          placeholder: "0x...",
          text: $recipient
        )

        TextFieldWithLabel(
          label: "Amount",
          placeholder: "1.23",
          text: $amount
        )

        TextFieldWithLabel(
          label: "Decimals",
          placeholder: "18",
          text: $decimals
        )

        PrimaryButton(
          title: isLoading ? "Sending..." : "Send ERC20",
          action: sendErc20,
          isLoading: isLoading
        )

        if let error = errorMessage {
          ErrorMessageView(message: error)
        }

        if let hash = txHash {
          SuccessMessageView(message: "TX Hash: \(hash)")
        }
      }
      .padding()
    }
    .navigationTitle("Send ERC20")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func sendErc20() {
    let token = tokenAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    let to = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
    let amountStr = amount.trimmingCharacters(in: .whitespacesAndNewlines)
    let decimalsStr = decimals.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !token.isEmpty else { errorMessage = "Please enter token address"; return }
    guard !to.isEmpty else { errorMessage = "Please enter recipient"; return }
    guard !amountStr.isEmpty else { errorMessage = "Please enter amount"; return }
    guard let dec = Int(decimalsStr), dec >= 0, dec <= 77 else {
      errorMessage = "Invalid decimals"
      return
    }

    isLoading = true
    errorMessage = nil
    txHash = nil

    Task {
      do {
        let baseUnits = try parseDecimalToBaseUnits(amountStr, decimals: dec)

        guard let abiData = Erc20.abi.data(using: .utf8),
              let abiArray = try JSONSerialization.jsonObject(with: abiData) as? [[String: Any]] else {
          throw DynamicSDKError.custom("Invalid Erc20 ABI")
        }

        let input = WriteContractInput(
          address: token,
          abi: abiArray,
          functionName: "transfer",
          args: [to, baseUnits]
        )

        let hash = try await DynamicSDK.instance().evm.writeContract(wallet: wallet, input: input)

        await MainActor.run {
          txHash = hash
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

  private func parseDecimalToBaseUnits(_ value: String, decimals: Int) throws -> BigUInt {
    let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { throw DynamicSDKError.custom("Amount is empty") }

    let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count <= 2 else { throw DynamicSDKError.custom("Invalid amount format") }

    let wholePart = String(parts[0].isEmpty ? "0" : parts[0])
    let fracPartRaw = parts.count == 2 ? String(parts[1]) : ""

    guard wholePart.range(of: #"^\d+$"#, options: .regularExpression) != nil else {
      throw DynamicSDKError.custom("Invalid amount")
    }
    guard fracPartRaw.isEmpty || fracPartRaw.range(of: #"^\d+$"#, options: .regularExpression) != nil else {
      throw DynamicSDKError.custom("Invalid amount")
    }

    let whole = BigUInt(wholePart) ?? 0

    let fracPadded: String
    if decimals == 0 {
      fracPadded = ""
    } else {
      let trimmedFrac = String(fracPartRaw.prefix(decimals))
      fracPadded = trimmedFrac.padding(toLength: decimals, withPad: "0", startingAt: 0)
    }

    let frac = fracPadded.isEmpty ? 0 : (BigUInt(fracPadded) ?? 0)
    let factor = BigUInt(10).power(decimals)
    return whole * factor + frac
  }
}


