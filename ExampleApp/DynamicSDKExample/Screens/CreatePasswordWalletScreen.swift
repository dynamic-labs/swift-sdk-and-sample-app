import SwiftUI
import DynamicSDKSwift

// Create a password-protected embedded wallet.
struct CreatePasswordWalletScreen: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var vm = CreatePasswordWalletViewModel()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("Create a new embedded wallet protected by a password. The password encrypts the wallet's key share and is required to unlock it later.")
          .font(.subheadline)
          .foregroundColor(.secondary)

        VStack(alignment: .leading, spacing: 8) {
          Text("Chain")
            .font(.subheadline)
            .fontWeight(.medium)

          Picker("Chain", selection: $vm.chain) {
            ForEach(EmbeddedWalletChain.allCases, id: \.rawValue) { chain in
              Text(chain.rawValue).tag(chain)
            }
          }
          .pickerStyle(.segmented)
        }

        SecureFieldWithLabel(
          label: "Password",
          placeholder: "Enter a password",
          text: $vm.password
        )

        SecureFieldWithLabel(
          label: "Confirm Password",
          placeholder: "Re-enter the password",
          text: $vm.confirmPassword
        )

        PrimaryButton(
          title: vm.isCreating ? "Creating..." : "Create Password Wallet",
          action: { Task { await vm.createWallet(onSuccess: { dismiss() }) } },
          isLoading: vm.isCreating,
          isDisabled: !vm.canSubmit
        )

        if let result = vm.resultMessage {
          SuccessMessageView(message: result)
        }

        if let error = vm.errorMessage {
          ErrorMessageView(message: error)
        }
      }
      .padding(16)
    }
    .navigationTitle("Create Password Wallet")
    .navigationBarTitleDisplayMode(.inline)
  }
}

@MainActor
final class CreatePasswordWalletViewModel: ObservableObject {
  @Published var chain: EmbeddedWalletChain = .evm
  @Published var password: String = ""
  @Published var confirmPassword: String = ""
  @Published var isCreating: Bool = false
  @Published var resultMessage: String?
  @Published var errorMessage: String?

  private let sdk = DynamicSDK.instance()

  var canSubmit: Bool {
    !password.isEmpty && !confirmPassword.isEmpty && !isCreating
  }

  func createWallet(onSuccess: @escaping () -> Void) async {
    resultMessage = nil
    errorMessage = nil

    guard password == confirmPassword else {
      errorMessage = "Passwords do not match."
      return
    }

    isCreating = true
    defer { isCreating = false }

    do {
      let wallet = try await sdk.wallets.embedded.createWallet(
        chain: chain,
        password: password
      )
      // Avoid logging/displaying any key material; only show the public address.
      resultMessage = "Created \(chain.rawValue) wallet: \(wallet.address)"
      password = ""
      confirmPassword = ""
      onSuccess()
    } catch {
      errorMessage = "Failed to create wallet: \(error.localizedDescription)"
    }
  }
}
