import SwiftUI
import DynamicSDKSwift

// Trusted Devices (Device Registration) screen.
struct TrustedDevicesScreen: View {
  @StateObject private var vm = TrustedDevicesViewModel()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        PrimaryButton(
          title: "Revoke All Devices",
          action: { vm.isRevokeAllConfirmPresented = true },
          isLoading: vm.isRevokingAll,
          isDisabled: vm.isLoading
        )

        DevicesStateCard(
          isLoading: vm.isLoading,
          error: vm.errorMessage,
          devices: vm.devices,
          onRetry: { Task { await vm.loadDevices() } },
          onRevoke: { device in vm.confirmRevoke(device) }
        )
      }
      .padding(16)
    }
    .navigationTitle("Trusted Devices")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { Task { await vm.loadDevices() } }
    .refreshable { await vm.loadDevices() }
    .alert(vm.alertTitle ?? "", isPresented: Binding(get: { vm.alertTitle != nil }, set: { _ in vm.alertTitle = nil; vm.alertMessage = nil })) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(vm.alertMessage ?? "")
    }
    .confirmationDialog("Revoke Device", isPresented: $vm.isRevokeConfirmPresented, titleVisibility: .visible) {
      Button("Revoke", role: .destructive) {
        Task { await vm.revokeConfirmed() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(vm.revokeConfirmMessage)
    }
    .confirmationDialog("Revoke All Devices", isPresented: $vm.isRevokeAllConfirmPresented, titleVisibility: .visible) {
      Button("Revoke All", role: .destructive) {
        Task { await vm.revokeAllDevices() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Are you sure you want to revoke all registered devices? This action cannot be undone.")
    }
  }
}

private struct DevicesStateCard: View {
  let isLoading: Bool
  let error: String?
  let devices: [RegisteredDevice]?
  let onRetry: () -> Void
  let onRevoke: (RegisteredDevice) -> Void

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
            Text("No registered devices")
              .fontWeight(.bold)
            Text("No trusted devices are currently registered for this account")
              .foregroundColor(.secondary)
              .font(.footnote)
          }
        } else {
          VStack(spacing: 12) {
            ForEach(Array(devices.enumerated()), id: \.offset) { _, device in
              RegisteredDeviceCard(
                device: device,
                onRevoke: { onRevoke(device) }
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

private struct RegisteredDeviceCard: View {
  let device: RegisteredDevice
  let onRevoke: () -> Void

  var body: some View {
    CardContainer {
      VStack(alignment: .leading, spacing: 8) {
        Text(device.displayText ?? "Unknown Device")
          .fontWeight(.bold)
          .font(.headline)

        Text("ID: \(device.id.prefix(8))...")
          .foregroundColor(.secondary)
          .font(.caption)

        if let type = device.type {
          Text("Type: \(type)")
            .foregroundColor(.secondary)
            .font(.caption)
        }

        Text("Created: \(device.createdAt)")
          .foregroundColor(.secondary)
          .font(.caption)

        if device.isCurrentDevice == true {
          Text("Current Device")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(4)
        }

        Button("Revoke", action: onRevoke)
          .buttonStyle(.bordered)
          .tint(.red)
          .frame(maxWidth: .infinity)
          .padding(.top, 4)
      }
    }
  }
}

@MainActor
final class TrustedDevicesViewModel: ObservableObject {
  @Published var devices: [RegisteredDevice]?
  @Published var isLoading: Bool = true
  @Published var isRevokingAll: Bool = false
  @Published var errorMessage: String?

  @Published var alertTitle: String?
  @Published var alertMessage: String?

  @Published var isRevokeConfirmPresented: Bool = false
  @Published var isRevokeAllConfirmPresented: Bool = false
  @Published var revokeConfirmMessage: String = ""
  private var pendingRevoke: RegisteredDevice?

  private let sdk = DynamicSDK.instance()

  func loadDevices() async {
    isLoading = true
    errorMessage = nil
    do {
      devices = try await sdk.deviceRegistration.getRegisteredDevices()
    } catch {
      errorMessage = "Failed to load registered devices: \(error)"
    }
    isLoading = false
  }

  func confirmRevoke(_ device: RegisteredDevice) {
    pendingRevoke = device
    revokeConfirmMessage = "Are you sure you want to revoke device \"\(device.displayText ?? device.id)\"? This action cannot be undone."
    isRevokeConfirmPresented = true
  }

  func revokeConfirmed() async {
    guard let device = pendingRevoke else { return }
    isLoading = true
    defer {
      isLoading = false
      pendingRevoke = nil
    }
    do {
      try await sdk.deviceRegistration.revokeRegisteredDevice(deviceRegistrationId: device.id)
      await loadDevices()
      alertTitle = "Success"
      alertMessage = "Device revoked successfully"
    } catch {
      alertTitle = "Error"
      alertMessage = "Failed to revoke device: \(error)"
    }
  }

  func revokeAllDevices() async {
    isRevokingAll = true
    defer { isRevokingAll = false }
    do {
      try await sdk.deviceRegistration.revokeAllRegisteredDevices()
      await loadDevices()
      alertTitle = "Success"
      alertMessage = "All devices revoked successfully"
    } catch {
      alertTitle = "Error"
      alertMessage = "Failed to revoke all devices: \(error)"
    }
  }
}
