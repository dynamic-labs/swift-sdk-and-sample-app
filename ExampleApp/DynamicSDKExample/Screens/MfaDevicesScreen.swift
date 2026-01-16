import SwiftUI
import DynamicSDKSwift

// MFA Devices screen (Flutter example parity).
struct MfaDevicesScreen: View {
  @StateObject private var vm = MfaDevicesViewModel()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        PrimaryButton(
          title: "Add MFA Device",
          action: { vm.navigateToAdd = true },
          isLoading: false,
          isDisabled: false
        )

        PrimaryButton(
          title: "Get New Recovery Codes",
          action: { vm.navigateToRecoveryCodes = true },
          isLoading: false,
          isDisabled: false
        )

        MfaStateCard(
          isLoading: vm.isLoading,
          error: vm.errorMessage,
          devices: vm.devices,
          onRetry: { Task { await vm.loadDevices() } },
          onAuthenticate: { device in vm.presentCodePrompt(for: .authenticate(device)) },
          onRegenerateBackupCodes: { device in Task { await vm.regenerateBackupCodes(device) } },
          onDelete: { device in vm.presentCodePrompt(for: .delete(device)) }
        )
      }
      .padding(16)
    }
    .navigationTitle("MFA Devices")
    .onAppear { Task { await vm.loadDevices() } }
    .refreshable { await vm.loadDevices() }
    .navigationDestination(isPresented: $vm.navigateToAdd) {
      MfaAddDeviceScreen(onFinished: { Task { await vm.loadDevices() } })
    }
    .navigationDestination(isPresented: $vm.navigateToRecoveryCodes) {
      MfaRecoveryCodesScreen()
    }
    .sheet(item: $vm.codePrompt) { prompt in
      CodeInputSheet(
        title: prompt.title,
        message: prompt.message,
        onCancel: { vm.codePrompt = nil },
        onSubmit: { code in Task { await vm.handleCodeSubmit(prompt: prompt, code: code) } }
      )
    }
    .sheet(item: $vm.codesSheet) { sheet in
      CodesSheet(title: sheet.title, codes: sheet.codes)
    }
    .alert(vm.alertTitle ?? "", isPresented: Binding(get: { vm.alertTitle != nil }, set: { _ in vm.alertTitle = nil; vm.alertMessage = nil })) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(vm.alertMessage ?? "")
    }
  }
}

private struct MfaStateCard: View {
  let isLoading: Bool
  let error: String?
  let devices: [MfaDevice]?
  let onRetry: () -> Void
  let onAuthenticate: (MfaDevice) -> Void
  let onRegenerateBackupCodes: (MfaDevice) -> Void
  let onDelete: (MfaDevice) -> Void

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
      } else if let devices {
        if devices.isEmpty {
          VStack(spacing: 8) {
            Text("No MFA devices configured")
              .fontWeight(.bold)
            Text("Add an MFA device to enhance your account security")
              .foregroundColor(.secondary)
              .font(.footnote)
          }
        } else {
          VStack(spacing: 12) {
            ForEach(Array(devices.enumerated()), id: \.offset) { _, device in
              MfaDeviceCard(
                device: device,
                onAuthenticate: { onAuthenticate(device) },
                onRegenerateBackupCodes: { onRegenerateBackupCodes(device) },
                onDelete: { onDelete(device) }
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

private struct MfaDeviceCard: View {
  let device: MfaDevice
  let onAuthenticate: () -> Void
  let onRegenerateBackupCodes: () -> Void
  let onDelete: () -> Void

  var body: some View {
    CardContainer {
      VStack(alignment: .leading, spacing: 8) {
        Text(device.type == .totp ? "Authenticator App" : (device.type?.rawValue ?? "Unknown"))
          .fontWeight(.bold)
          .font(.headline)

        Text("Device ID: \((device.id ?? "N/A").prefix(8))...")
          .foregroundColor(.secondary)
          .font(.caption)

        VStack(spacing: 8) {
          Button("Authenticate device", action: onAuthenticate)
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

          Button("Regenerate backup code", action: onRegenerateBackupCodes)
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
final class MfaDevicesViewModel: ObservableObject {
  @Published var devices: [MfaDevice]?
  @Published var isLoading: Bool = true
  @Published var errorMessage: String?

  @Published var navigateToAdd: Bool = false
  @Published var navigateToRecoveryCodes: Bool = false

  @Published var codePrompt: CodePrompt?
  @Published var codesSheet: CodesSheetModel?

  @Published var alertTitle: String?
  @Published var alertMessage: String?

  private let sdk = DynamicSDK.instance()

  enum Action {
    case authenticate(MfaDevice)
    case delete(MfaDevice)
  }

  func loadDevices() async {
    isLoading = true
    errorMessage = nil
    do {
      devices = try await sdk.mfa.getUserDevices()
    } catch {
      errorMessage = "Failed to load MFA devices: \(error)"
    }
    isLoading = false
  }

  func presentCodePrompt(for action: Action) {
    switch action {
    case .authenticate:
      codePrompt = CodePrompt(
        id: UUID(),
        title: "Authenticate device",
        message: "Enter the TOTP code from your authenticator app to authenticate this device",
        action: action
      )
    case .delete:
      codePrompt = CodePrompt(
        id: UUID(),
        title: "Authenticate device",
        message: "Enter the TOTP code from your authenticator app to delete this MFA device",
        action: action
      )
    }
  }

  func handleCodeSubmit(prompt: CodePrompt, code: String) async {
    codePrompt = nil
    let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    switch prompt.action {
    case .authenticate(let device):
      await authenticateDevice(device, code: trimmed)
    case .delete(let device):
      await deleteDevice(device, code: trimmed)
    }
  }

  private func authenticateDevice(_ device: MfaDevice, code: String) async {
    guard let id = device.id else { return }
    do {
      let token = try await sdk.mfa.authenticateDevice(
        params: MfaAuthenticateDevice(
          code: code,
          deviceId: id,
          createMfaToken: MfaCreateToken(singleUse: true)
        )
      )

      alertTitle = "Success"
      alertMessage = "Device authenticated successfully\n\nMFA Token: \(token ?? "nil")"
    } catch {
      alertTitle = "Error"
      alertMessage = "Failed to authenticate device: \(error)"
    }
  }

  func regenerateBackupCodes(_ device: MfaDevice) async {
    do {
      let codes = try await sdk.mfa.getRecoveryCodes(generateNewCodes: true)
      codesSheet = CodesSheetModel(id: UUID(), title: "Backup Codes", codes: codes)
    } catch {
      alertTitle = "Error"
      alertMessage = "Failed to get backup codes: \(error)"
    }
  }

  private func deleteDevice(_ device: MfaDevice, code: String) async {
    guard let id = device.id else { return }
    do {
      let token = try await sdk.mfa.authenticateDevice(
        params: MfaAuthenticateDevice(
          code: code,
          deviceId: id,
          createMfaToken: MfaCreateToken(singleUse: true)
        )
      )

      guard let token, !token.isEmpty else {
        alertTitle = "Error"
        alertMessage = "Failed to authenticate device"
        return
      }

      try await sdk.mfa.deleteUserDevice(deviceId: id, mfaAuthToken: token)
      await loadDevices()
      alertTitle = "Success"
      alertMessage = "Device deleted successfully"
    } catch {
      alertTitle = "Error"
      alertMessage = "Failed to delete MFA device: \(error)"
    }
  }
}

struct CodePrompt: Identifiable {
  let id: UUID
  let title: String
  let message: String
  let action: MfaDevicesViewModel.Action
}


