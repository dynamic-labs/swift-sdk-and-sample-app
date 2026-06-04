import SwiftUI
import DynamicSDKSwift

// Import a raw private key into a new Dynamic WaaS wallet.
struct ImportPrivateKeyScreen: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var vm = ImportPrivateKeyViewModel()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("Import an existing private key into a new Dynamic embedded (WaaS) wallet. The key is forwarded to the secure webview and is not stored or logged by the app.")
          .font(.subheadline)
          .foregroundColor(.secondary)

        VStack(alignment: .leading, spacing: 8) {
          Text("Chain")
            .font(.subheadline)
            .fontWeight(.medium)

          Picker("Chain", selection: $vm.chain) {
            ForEach(WaasChain.allCases, id: \.rawValue) { chain in
              Text(chain.rawValue).tag(chain)
            }
          }
          .pickerStyle(.segmented)
        }

        SecureFieldWithLabel(
          label: "Private Key",
          placeholder: "Enter the raw private key",
          text: $vm.privateKey
        )

        SecureFieldWithLabel(
          label: "Password (optional)",
          placeholder: "Encrypt the imported key share",
          text: $vm.password
        )

        PrimaryButton(
          title: vm.isImporting ? "Importing..." : "Import Private Key",
          action: { Task { await vm.importKey(onSuccess: { dismiss() }) } },
          isLoading: vm.isImporting,
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
    .navigationTitle("Import Private Key")
    .navigationBarTitleDisplayMode(.inline)
  }
}

@MainActor
final class ImportPrivateKeyViewModel: ObservableObject {
  @Published var chain: WaasChain = .evm
  @Published var privateKey: String = ""
  @Published var password: String = ""
  @Published var isImporting: Bool = false
  @Published var resultMessage: String?
  @Published var errorMessage: String?

  private let sdk = DynamicSDK.instance()

  var canSubmit: Bool {
    !privateKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isImporting
  }

  func importKey(onSuccess: @escaping () -> Void) async {
    resultMessage = nil
    errorMessage = nil

    let key = privateKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty else { return }

    isImporting = true
    defer { isImporting = false }

    do {
      let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
      try await sdk.wallets.waas.importPrivateKey(
        chain: chain,
        privateKey: key,
        password: trimmedPassword.isEmpty ? nil : trimmedPassword
      )
      // Clear the sensitive input as soon as the import completes.
      privateKey = ""
      password = ""
      resultMessage = "Imported \(chain.rawValue) private key successfully."
      onSuccess()
    } catch {
      errorMessage = "Failed to import private key: \(error.localizedDescription)"
    }
  }
}
