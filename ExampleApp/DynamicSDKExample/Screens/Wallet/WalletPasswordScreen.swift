import SwiftUI
import DynamicSDKSwift

struct WalletPasswordScreen: View {
  let wallet: BaseWallet

  @Environment(\.colorScheme) var colorScheme
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var successMessage: String?

  // Recovery state
  @State private var recoveryStateText: String?

  // Unlock
  @State private var unlockPassword = ""

  // Set password
  @State private var setNewPassword = ""

  // Update password
  @State private var currentPassword = ""
  @State private var newPassword = ""

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        // --- Check Recovery State ---
        SectionHeader(title: "Check Recovery State")

        Text("Check if the wallet is locked (encrypted) or ready.")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.horizontal)

        Button(action: { Task { await checkRecoveryState() } }) {
          HStack {
            if isLoading {
              ProgressView().scaleEffect(0.8)
            } else {
              Image(systemName: "magnifyingglass")
            }
            Text(isLoading ? "Checking..." : "Check Recovery State")
            Spacer()
          }
          .padding()
          .frame(maxWidth: .infinity)
          .background(Color.blue.opacity(0.1))
          .foregroundColor(.blue)
          .cornerRadius(8)
        }
        .disabled(isLoading)
        .padding(.horizontal)

        if let recoveryStateText {
          Text(recoveryStateText)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .padding(.horizontal)
        }

        Divider().padding(.horizontal)

        // --- Unlock Wallet ---
        SectionHeader(title: "Unlock Wallet")

        Text("Unlock a password-protected wallet for the current session.")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.horizontal)

        SecureField("Enter password to unlock", text: $unlockPassword)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .disabled(isLoading)
          .padding(.horizontal)

        Button(action: { Task { await unlockWallet() } }) {
          HStack {
            Image(systemName: "lock.open")
            Text("Unlock Wallet")
            Spacer()
          }
          .padding()
          .frame(maxWidth: .infinity)
          .background(Color.green.opacity(0.1))
          .foregroundColor(.green)
          .cornerRadius(8)
        }
        .disabled(isLoading || unlockPassword.trimmingCharacters(in: .whitespaces).isEmpty)
        .padding(.horizontal)

        Divider().padding(.horizontal)

        // --- Set Password ---
        SectionHeader(title: "Set Password")

        Text("Set a new password on a wallet that doesn't have one yet.")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.horizontal)

        SecureField("New password", text: $setNewPassword)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .disabled(isLoading)
          .padding(.horizontal)

        Button(action: { Task { await setPassword() } }) {
          HStack {
            Image(systemName: "key.fill")
            Text("Set Password")
            Spacer()
          }
          .padding()
          .frame(maxWidth: .infinity)
          .background(Color.purple.opacity(0.1))
          .foregroundColor(.purple)
          .cornerRadius(8)
        }
        .disabled(
          isLoading
            || setNewPassword.trimmingCharacters(in: .whitespaces).isEmpty
        )
        .padding(.horizontal)

        Divider().padding(.horizontal)

        // --- Update Password ---
        SectionHeader(title: "Update Password")

        Text("Change the password for all wallets on this account.")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.horizontal)

        SecureField("Current password", text: $currentPassword)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .disabled(isLoading)
          .padding(.horizontal)

        SecureField("New password", text: $newPassword)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .disabled(isLoading)
          .padding(.horizontal)

        Button(action: { Task { await updatePassword() } }) {
          HStack {
            Image(systemName: "key.fill")
            Text("Update Password")
            Spacer()
          }
          .padding()
          .frame(maxWidth: .infinity)
          .background(Color.orange.opacity(0.1))
          .foregroundColor(.orange)
          .cornerRadius(8)
        }
        .disabled(
          isLoading
            || currentPassword.trimmingCharacters(in: .whitespaces).isEmpty
            || newPassword.trimmingCharacters(in: .whitespaces).isEmpty
        )
        .padding(.horizontal)

        // --- Feedback ---
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

        Spacer()
      }
      .padding(.vertical)
    }
    .navigationTitle("Wallet Password")
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: - Actions

  @MainActor
  private func checkRecoveryState() async {
    isLoading = true
    errorMessage = nil
    successMessage = nil
    do {
      let state = try await DynamicSDK.instance().wallets.waas.getWalletRecoveryState(
        wallet: wallet
      )
      recoveryStateText =
        "State: \(state.walletReadyState), Password encrypted: \(state.isPasswordEncrypted)"
    } catch {
      errorMessage = "Error: \(error.localizedDescription)"
    }
    isLoading = false
  }

  @MainActor
  private func unlockWallet() async {
    let password = unlockPassword.trimmingCharacters(in: .whitespaces)
    guard !password.isEmpty else { return }
    isLoading = true
    errorMessage = nil
    successMessage = nil
    do {
      try await DynamicSDK.instance().wallets.waas.unlockWallet(
        wallet: wallet,
        password: password
      )
      successMessage = "Wallet unlocked"
      unlockPassword = ""
    } catch {
      errorMessage = "Unlock failed: \(error.localizedDescription)"
    }
    isLoading = false
  }

  @MainActor
  private func setPassword() async {
    let newPwd = setNewPassword.trimmingCharacters(in: .whitespaces)
    guard !newPwd.isEmpty else { return }
    isLoading = true
    errorMessage = nil
    successMessage = nil
    do {
      try await DynamicSDK.instance().wallets.waas.setPassword(
        wallet: wallet,
        newPassword: newPwd
      )
      successMessage = "Password set"
      setNewPassword = ""
    } catch {
      errorMessage = "Set password failed: \(error.localizedDescription)"
    }
    isLoading = false
  }

  @MainActor
  private func updatePassword() async {
    let current = currentPassword.trimmingCharacters(in: .whitespaces)
    let newPwd = newPassword.trimmingCharacters(in: .whitespaces)
    guard !current.isEmpty, !newPwd.isEmpty else { return }
    isLoading = true
    errorMessage = nil
    successMessage = nil
    do {
      try await DynamicSDK.instance().wallets.waas.updatePassword(
        wallet: wallet,
        existingPassword: current,
        newPassword: newPwd
      )
      successMessage = "Password updated"
      currentPassword = ""
      newPassword = ""
    } catch {
      errorMessage = "Update password failed: \(error.localizedDescription)"
    }
    isLoading = false
  }
}

private struct SectionHeader: View {
  let title: String

  var body: some View {
    Text(title)
      .font(.title3)
      .fontWeight(.bold)
      .padding(.horizontal)
  }
}
