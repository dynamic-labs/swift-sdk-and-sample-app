import SwiftUI
import DynamicSDKSwift

// Recovery Codes screen (Flutter example parity).
struct MfaRecoveryCodesScreen: View {
  @StateObject private var vm = MfaRecoveryCodesViewModel()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        CardContainer {
          VStack(alignment: .leading, spacing: 12) {
            Text("Authenticate Recovery Code")
              .font(.headline)
              .fontWeight(.bold)
            Text("Enter a recovery code to authenticate and receive an MFA token.")
              .foregroundColor(.secondary)
              .font(.subheadline)

            TextFieldWithLabel(
              label: "Recovery Code",
              placeholder: "Enter recovery code",
              text: $vm.recoveryCode
            )

            Button(vm.isLoading ? "Loading…" : "Authenticate Recovery Code") {
              Task { await vm.authenticateRecoveryCode() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isLoading || vm.recoveryCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }

        Divider()

        CardContainer {
          VStack(alignment: .leading, spacing: 12) {
            Text("Get New Recovery Codes")
              .font(.headline)
              .fontWeight(.bold)
            Text("Generate new recovery codes. This will invalidate any existing recovery codes.")
              .foregroundColor(.secondary)
              .font(.subheadline)

            Button(vm.isLoading ? "Loading…" : "Get New Recovery Codes") {
              Task { await vm.getNewRecoveryCodes() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isLoading)
          }
        }

        Divider()

        CardContainer {
          VStack(alignment: .leading, spacing: 12) {
            Text("Check Pending Acknowledgment")
              .font(.headline)
              .fontWeight(.bold)
            Text("Check if you have pending recovery codes that need to be acknowledged.")
              .foregroundColor(.secondary)
              .font(.subheadline)

            Button(vm.isLoading ? "Loading…" : "Check Pending") {
              Task { await vm.checkPending() }
            }
            .buttonStyle(.bordered)
            .disabled(vm.isLoading)

            if let pending = vm.isPending {
              Text(pending ? "You have pending recovery codes that need to be acknowledged" : "No pending recovery codes acknowledgment required")
                .font(.footnote)
                .foregroundColor(.secondary)
            }
          }
        }

        CardContainer {
          VStack(alignment: .leading, spacing: 12) {
            Text("Acknowledge Recovery Codes")
              .font(.headline)
              .fontWeight(.bold)
            Text("Acknowledge your recovery codes so they can be used.")
              .foregroundColor(.secondary)
              .font(.subheadline)

            Button(vm.isLoading ? "Loading…" : "Acknowledge") {
              Task { await vm.acknowledge() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isLoading)
          }
        }
      }
      .padding(16)
    }
    .navigationTitle("Recovery Codes")
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

@MainActor
final class MfaRecoveryCodesViewModel: ObservableObject {
  @Published var recoveryCode: String = ""
  @Published var isPending: Bool?
  @Published var isLoading: Bool = false

  @Published var codesSheet: CodesSheetModel?
  @Published var alertTitle: String?
  @Published var alertMessage: String?

  private let sdk = DynamicSDK.instance()

  func authenticateRecoveryCode() async {
    guard !recoveryCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      _ = try await sdk.mfa.authenticateRecoveryCode(
        code: MfaAuthenticateRecoveryCode(
          code: recoveryCode.trimmingCharacters(in: .whitespacesAndNewlines),
          createMfaToken: MfaCreateToken(singleUse: true)
        )
      )
      alertTitle = "Success"
      alertMessage = "Recovery code authenticated successfully"
      recoveryCode = ""
    } catch {
      alertTitle = "Error"
      alertMessage = "Failed to authenticate recovery code. Please check your code and try again."
    }
  }

  func getNewRecoveryCodes() async {
    isLoading = true
    defer { isLoading = false }
    do {
      let codes = try await sdk.mfa.getNewRecoveryCodes()
      codesSheet = CodesSheetModel(id: UUID(), title: "Recovery Codes", codes: codes)
    } catch {
      alertTitle = "Error"
      alertMessage = "Failed to get new recovery codes: \(error)"
    }
  }

  func checkPending() async {
    isLoading = true
    defer { isLoading = false }
    do {
      isPending = try await sdk.mfa.isPendingRecoveryCodesAcknowledgment()
    } catch {
      alertTitle = "Error"
      alertMessage = "Failed to check pending acknowledgment: \(error)"
    }
  }

  func acknowledge() async {
    isLoading = true
    defer { isLoading = false }
    do {
      try await sdk.mfa.completeAcknowledgement()
      alertTitle = "Success"
      alertMessage = "Recovery codes acknowledged successfully"
    } catch {
      alertTitle = "Error"
      alertMessage = "Failed to acknowledge recovery codes: \(error)"
    }
  }
}


