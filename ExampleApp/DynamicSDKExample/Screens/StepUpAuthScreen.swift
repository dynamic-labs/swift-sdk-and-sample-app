import SwiftUI
import DynamicSDKSwift

// Step-Up Authentication screen.
struct StepUpAuthScreen: View {
  @StateObject private var vm = StepUpAuthViewModel()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        TextFieldWithLabel(
          label: "Scope",
          placeholder: "e.g. wallet:send",
          text: $vm.scope
        )

        PrimaryButton(
          title: "Check Step-Up Required",
          action: { Task { await vm.checkStepUpRequired() } },
          isLoading: vm.isCheckingRequired,
          isDisabled: vm.scope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )

        PrimaryButton(
          title: "Prompt Step-Up Auth",
          action: { Task { await vm.promptStepUpAuth() } },
          isLoading: vm.isPrompting,
          isDisabled: false
        )

        PrimaryButton(
          title: "Prompt MFA",
          action: { Task { await vm.promptMfa() } },
          isLoading: vm.isPromptingMfa,
          isDisabled: false
        )

        PrimaryButton(
          title: "Prompt Reauthenticate",
          action: { Task { await vm.promptReauthenticate() } },
          isLoading: vm.isPromptingReauth,
          isDisabled: false
        )

        PrimaryButton(
          title: "Reset State",
          action: { Task { await vm.resetState() } },
          isLoading: false,
          isDisabled: false
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
    .navigationTitle("Step-Up Auth")
    .navigationBarTitleDisplayMode(.inline)
  }
}

@MainActor
final class StepUpAuthViewModel: ObservableObject {
  @Published var scope: String = ""
  @Published var isCheckingRequired: Bool = false
  @Published var isPrompting: Bool = false
  @Published var isPromptingMfa: Bool = false
  @Published var isPromptingReauth: Bool = false
  @Published var resultMessage: String?
  @Published var errorMessage: String?

  private let sdk = DynamicSDK.instance()

  func checkStepUpRequired() async {
    let trimmed = scope.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    isCheckingRequired = true
    resultMessage = nil
    errorMessage = nil
    defer { isCheckingRequired = false }
    do {
      let required = try await sdk.stepUpAuth.isStepUpRequired(scope: trimmed)
      resultMessage = "Step-up required for \"\(trimmed)\": \(required)"
    } catch {
      errorMessage = "Failed to check step-up: \(error)"
    }
  }

  func promptStepUpAuth() async {
    isPrompting = true
    resultMessage = nil
    errorMessage = nil
    defer { isPrompting = false }
    do {
      let scopes = scopesArray()
      let token = try await sdk.stepUpAuth.promptStepUpAuth(requestedScopes: scopes)
      resultMessage = "Step-up auth token: \(token ?? "nil")"
    } catch {
      errorMessage = "Failed to prompt step-up auth: \(error)"
    }
  }

  func promptMfa() async {
    isPromptingMfa = true
    resultMessage = nil
    errorMessage = nil
    defer { isPromptingMfa = false }
    do {
      let scopes = scopesArray()
      let token = try await sdk.stepUpAuth.promptMfa(requestedScopes: scopes)
      resultMessage = "MFA token: \(token ?? "nil")"
    } catch {
      errorMessage = "Failed to prompt MFA: \(error)"
    }
  }

  func promptReauthenticate() async {
    isPromptingReauth = true
    resultMessage = nil
    errorMessage = nil
    defer { isPromptingReauth = false }
    do {
      let scopes = scopesArray()
      let token = try await sdk.stepUpAuth.promptReauthenticate(requestedScopes: scopes)
      resultMessage = "Reauthenticate token: \(token ?? "nil")"
    } catch {
      errorMessage = "Failed to prompt reauthenticate: \(error)"
    }
  }

  func resetState() async {
    resultMessage = nil
    errorMessage = nil
    do {
      try await sdk.stepUpAuth.resetState()
      resultMessage = "Step-up auth state reset successfully"
    } catch {
      errorMessage = "Failed to reset state: \(error)"
    }
  }

  private func scopesArray() -> [String]? {
    let trimmed = scope.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return trimmed.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
  }
}
