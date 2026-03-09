import SwiftUI
import DynamicSDKSwift

struct CreatePasswordWalletScreen: View {
  @Environment(\.dismiss) var dismiss
  @State private var selectedChain: EmbeddedWalletChain = .evm
  @State private var password = ""
  @State private var isCreating = false
  @State private var errorMessage: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("Create an embedded wallet protected by a password. Choose the chain and optionally enter a password.")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.horizontal)

        // Chain picker
        HStack {
          Text("Chain")
            .font(.subheadline)
            .fontWeight(.semibold)
          Spacer()
          Menu {
            ForEach(EmbeddedWalletChain.allCases, id: \.rawValue) { chain in
              Button(chain.rawValue) {
                selectedChain = chain
              }
            }
          } label: {
            HStack {
              Text(selectedChain.rawValue)
              Image(systemName: "chevron.down")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.15))
            .cornerRadius(8)
          }
          .disabled(isCreating)
        }
        .padding(.horizontal)

        // Password field
        VStack(alignment: .leading, spacing: 4) {
          Text("Password (optional)")
            .font(.subheadline)
            .fontWeight(.semibold)
          SecureField("Leave empty for no password", text: $password)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .disabled(isCreating)
        }
        .padding(.horizontal)

        // Create button
        Button(action: { Task { await createWallet() } }) {
          HStack {
            if isCreating {
              ProgressView().scaleEffect(0.8)
            } else {
              Image(systemName: "plus.circle.fill")
            }
            Text(isCreating ? "Creating..." : "Create wallet")
            Spacer()
          }
          .padding()
          .frame(maxWidth: .infinity)
          .background(Color.blue)
          .foregroundColor(.white)
          .cornerRadius(8)
        }
        .disabled(isCreating)
        .padding(.horizontal)

        if let errorMessage {
          ErrorMessageView(message: errorMessage)
            .padding(.horizontal)
        }
      }
      .padding(.vertical)
    }
    .navigationTitle("Create Password Wallet")
    .navigationBarTitleDisplayMode(.inline)
  }

  @MainActor
  private func createWallet() async {
    isCreating = true
    errorMessage = nil
    let pwd = password.trimmingCharacters(in: .whitespaces)
    do {
      _ = try await DynamicSDK.instance().wallets.embedded.createWallet(
        chain: selectedChain,
        password: pwd.isEmpty ? nil : pwd
      )
      dismiss()
    } catch {
      errorMessage = "Create wallet failed: \(error.localizedDescription)"
    }
    isCreating = false
  }
}
