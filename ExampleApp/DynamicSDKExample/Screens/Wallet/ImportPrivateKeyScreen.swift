import SwiftUI
import DynamicSDKSwift

struct ImportPrivateKeyScreen: View {
  @Environment(\.dismiss) var dismiss
  @Environment(\.colorScheme) var colorScheme

  @State private var selectedChain: WaasChain = .evm
  @State private var privateKey: String = ""
  @State private var selectedScheme: ThresholdSignatureScheme? = nil
  @State private var publicAddressCheck: String = ""
  @State private var addressType: String = ""
  @State private var password: String = ""
  @State private var isImporting = false
  @State private var errorMessage: String?
  @State private var successMessage: String?

  private let sdk = DynamicSDK.instance()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("Import a raw private key into a new Dynamic WaaS wallet on the chosen chain. The webview-controller looks up the WaaS connector for this chain — no pre-existing wallet required.")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.horizontal)

        // Chain picker
        VStack(alignment: .leading, spacing: 4) {
          Text("Chain")
            .font(.subheadline)
            .fontWeight(.semibold)
          Menu {
            ForEach(WaasChain.allCases, id: \.self) { chain in
              Button(chain.rawValue) { selectedChain = chain }
            }
          } label: {
            HStack {
              Text(selectedChain.rawValue)
              Spacer()
              Image(systemName: "chevron.down")
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .foregroundColor(colorScheme == .dark ? .white : .blue)
            .cornerRadius(8)
          }
          .disabled(isImporting)
        }
        .padding(.horizontal)

        // Private key
        VStack(alignment: .leading, spacing: 4) {
          Text("Private key")
            .font(.subheadline)
            .fontWeight(.semibold)
          SecureField("Enter raw private key", text: $privateKey)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .disabled(isImporting)
        }
        .padding(.horizontal)

        // Threshold signature scheme
        VStack(alignment: .leading, spacing: 4) {
          Text("Threshold signature scheme")
            .font(.subheadline)
            .fontWeight(.semibold)
          Menu {
            Button("Connector default") { selectedScheme = nil }
            ForEach(ThresholdSignatureScheme.allCases, id: \.self) { scheme in
              Button(scheme.rawValue) { selectedScheme = scheme }
            }
          } label: {
            HStack {
              Text(selectedScheme?.rawValue ?? "Connector default")
              Spacer()
              Image(systemName: "chevron.down")
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .foregroundColor(colorScheme == .dark ? .white : .blue)
            .cornerRadius(8)
          }
          .disabled(isImporting)
        }
        .padding(.horizontal)

        // Public address check (optional)
        VStack(alignment: .leading, spacing: 4) {
          Text("Public address check (optional)")
            .font(.subheadline)
            .fontWeight(.semibold)
          TextField("Expected public address", text: $publicAddressCheck)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .disabled(isImporting)
        }
        .padding(.horizontal)

        // Address type (Bitcoin)
        if selectedChain == .btc {
          VStack(alignment: .leading, spacing: 4) {
            Text("Address type (BTC)")
              .font(.subheadline)
              .fontWeight(.semibold)
            TextField("e.g. segwit, taproot, legacy", text: $addressType)
              .textFieldStyle(RoundedBorderTextFieldStyle())
              .autocapitalization(.none)
              .disableAutocorrection(true)
              .disabled(isImporting)
          }
          .padding(.horizontal)
        }

        // Password (optional)
        VStack(alignment: .leading, spacing: 4) {
          Text("Password (optional)")
            .font(.subheadline)
            .fontWeight(.semibold)
          SecureField("Encrypt key shares with a password", text: $password)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .disabled(isImporting)
        }
        .padding(.horizontal)

        // Import button
        Button(action: { Task { await importKey() } }) {
          HStack {
            if isImporting {
              ProgressView().scaleEffect(0.8)
            } else {
              Image(systemName: "square.and.arrow.down")
            }
            Text(isImporting ? "Importing..." : "Import Private Key")
            Spacer()
          }
          .padding()
          .frame(maxWidth: .infinity)
          .background(Color.blue)
          .foregroundColor(.white)
          .cornerRadius(8)
        }
        .disabled(
          isImporting
            || privateKey.trimmingCharacters(in: .whitespaces).isEmpty
        )
        .padding(.horizontal)

        if let errorMessage {
          ErrorMessageView(message: errorMessage)
            .padding(.horizontal)
        }

        if let successMessage {
          Text(successMessage)
            .font(.caption)
            .foregroundColor(.green)
            .padding(.horizontal)
        }
      }
      .padding(.vertical)
    }
    .navigationTitle("Import Private Key")
    .navigationBarTitleDisplayMode(.inline)
  }

  @MainActor
  private func importKey() async {
    let key = privateKey.trimmingCharacters(in: .whitespaces)
    guard !key.isEmpty else { return }
    let check = publicAddressCheck.trimmingCharacters(in: .whitespaces)
    let addr = addressType.trimmingCharacters(in: .whitespaces)
    let pwd = password.trimmingCharacters(in: .whitespaces)

    isImporting = true
    errorMessage = nil
    successMessage = nil
    do {
      try await sdk.wallets.waas.importPrivateKey(
        chain: selectedChain,
        privateKey: key,
        thresholdSignatureScheme: selectedScheme,
        publicAddressCheck: check.isEmpty ? nil : check,
        addressType: addr.isEmpty ? nil : addr,
        password: pwd.isEmpty ? nil : pwd
      )
      successMessage = "Private key imported"
      privateKey = ""
      publicAddressCheck = ""
      addressType = ""
      password = ""
    } catch {
      errorMessage = "Import failed: \(error.localizedDescription)"
    }
    isImporting = false
  }
}
