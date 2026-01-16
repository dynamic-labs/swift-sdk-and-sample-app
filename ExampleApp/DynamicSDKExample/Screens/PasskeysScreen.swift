import SwiftUI
import DynamicSDKSwift

// Passkeys screen (Flutter example parity).
struct PasskeysScreen: View {
  @StateObject private var vm = PasskeysViewModel()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Button {
          Task { await vm.registerPasskey() }
        } label: {
          Label("Register Passkey", systemImage: "plus")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(vm.isLoading)

        PasskeysStateCard(
          isLoading: vm.isLoading,
          error: vm.errorMessage,
          passkeys: vm.passkeys,
          onRetry: { Task { await vm.loadPasskeys() } },
          onAuthenticateMFA: { _ in Task { await vm.authenticateMfa() } },
          onDelete: { passkey in vm.confirmDelete(passkey) }
        )
      }
      .padding(16)
    }
    .navigationTitle("Passkeys")
    .onAppear { Task { await vm.loadPasskeys() } }
    .refreshable { await vm.loadPasskeys() }
    .alert(vm.alertTitle ?? "", isPresented: Binding(get: { vm.alertTitle != nil }, set: { _ in vm.alertTitle = nil; vm.alertMessage = nil })) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(vm.alertMessage ?? "")
    }
    .confirmationDialog("Delete Passkey", isPresented: $vm.isDeleteConfirmPresented, titleVisibility: .visible) {
      Button("Delete", role: .destructive) {
        Task { await vm.deleteConfirmed() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(vm.deleteConfirmMessage)
    }
  }
}

private struct PasskeysStateCard: View {
  let isLoading: Bool
  let error: String?
  let passkeys: [UserPasskey]?
  let onRetry: () -> Void
  let onAuthenticateMFA: (UserPasskey) -> Void
  let onDelete: (UserPasskey) -> Void

  var body: some View {
    CardContainer {
      if isLoading {
        HStack { Spacer(); ProgressView(); Spacer() }
      } else if let error {
        VStack(spacing: 12) {
          Text(error).foregroundColor(.red)
          Button("Retry", action: onRetry)
            .buttonStyle(.borderedProminent)
        }
      } else if let passkeys {
        if passkeys.isEmpty {
          VStack(spacing: 8) {
            Text("No passkeys configured").fontWeight(.bold)
            Text("Register a passkey to enhance your account security")
              .foregroundColor(.secondary)
              .font(.footnote)
          }
        } else {
          VStack(spacing: 12) {
            ForEach(Array(passkeys.enumerated()), id: \.offset) { _, passkey in
              PasskeyCard(
                passkey: passkey,
                onAuthenticateMFA: { onAuthenticateMFA(passkey) },
                onDelete: { onDelete(passkey) }
              )
            }
          }
        }
      } else {
        EmptyView()
      }
    }
  }
}

private struct PasskeyCard: View {
  let passkey: UserPasskey
  let onAuthenticateMFA: () -> Void
  let onDelete: () -> Void

  var body: some View {
    CardContainer {
      VStack(alignment: .leading, spacing: 8) {
        Text(passkey.id)
          .fontWeight(.bold)
          .font(.headline)

        Text("ID: \(passkey.id.prefix(8))...")
          .foregroundColor(.secondary)
          .font(.caption)

        Text("Created: \(passkey.createdAt.yyyyMmDd)")
          .foregroundColor(.secondary)
          .font(.caption)

        if let last = passkey.lastUsedAt {
          Text("Last used: \(last.yyyyMmDd)")
            .foregroundColor(.secondary)
            .font(.caption)
        }

        if passkey.isDefault == true {
          Text("Default")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(4)
        }

        VStack(spacing: 8) {
          Button("Authenticate MFA", action: onAuthenticateMFA)
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

          Button("Delete", action: onDelete)
            .buttonStyle(.bordered)
            .tint(.red)
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
      }
    }
  }
}

@MainActor
final class PasskeysViewModel: ObservableObject {
  @Published var passkeys: [UserPasskey]?
  @Published var isLoading: Bool = true
  @Published var errorMessage: String?

  @Published var alertTitle: String?
  @Published var alertMessage: String?

  @Published var isDeleteConfirmPresented: Bool = false
  @Published var deleteConfirmMessage: String = ""
  private var pendingDelete: UserPasskey?

  private let sdk = DynamicSDK.instance()

  func loadPasskeys() async {
    isLoading = true
    errorMessage = nil
    do {
      passkeys = try await sdk.passkeys.getPasskeys()
    } catch {
      errorMessage = "Failed to load passkeys: \(error)"
    }
    isLoading = false
  }

  func registerPasskey() async {
    isLoading = true
    defer { isLoading = false }
    do {
      _ = try await sdk.passkeys.registerPasskey()
      alertTitle = "Success"
      alertMessage = "Passkey registered successfully"
      await loadPasskeys()
    } catch {
      alertTitle = "Error"
      alertMessage = "Failed to register passkey: \(error)"
    }
  }

  func authenticateMfa() async {
    isLoading = true
    defer { isLoading = false }
    do {
      let response = try await sdk.passkeys.authenticatePasskeyMFA(
        createMfaToken: MfaCreateToken(singleUse: true),
        relatedOriginRpId: nil
      )
      alertTitle = "Success"
      alertMessage = "Passkey authenticated successfully\n\nToken: \(response.jwt ?? "nil")"
    } catch {
      alertTitle = "Error"
      alertMessage = "Failed to authenticate passkey: \(error)"
    }
  }

  func confirmDelete(_ passkey: UserPasskey) {
    pendingDelete = passkey
    deleteConfirmMessage = "Are you sure you want to delete passkey \"\(passkey.id)\"? This action cannot be undone."
    isDeleteConfirmPresented = true
  }

  func deleteConfirmed() async {
    guard let passkey = pendingDelete else { return }
    isLoading = true
    defer {
      isLoading = false
      pendingDelete = nil
    }
    do {
      try await sdk.passkeys.deletePasskey(DeletePasskeyRequest(passkeyId: passkey.id))
      await loadPasskeys()
      alertTitle = "Success"
      alertMessage = "Passkey deleted successfully"
    } catch {
      alertTitle = "Error"
      alertMessage = "Failed to delete passkey: \(error)"
    }
  }
}


