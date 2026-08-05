import SwiftUI
import DynamicSDKSwift

// Step-Up Authentication screen.
struct StepUpAuthScreen: View {
  @StateObject private var vm = StepUpAuthViewModel()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Scope")
            .font(.subheadline)
            .fontWeight(.medium)

          Picker("Scope", selection: $vm.scope) {
            Text("None").tag(TokenScope?.none)
            ForEach(TokenScope.allCases, id: \.rawValue) { scope in
              Text(scope.rawValue).tag(TokenScope?.some(scope))
            }
          }
          .pickerStyle(.menu)
        }

        PrimaryButton(
          title: "Check Step-Up Required",
          action: { Task { await vm.checkStepUpRequired() } },
          isLoading: vm.isCheckingRequired,
          isDisabled: vm.scope == nil
        )

        Divider()

        ScopeMultiSelect(selection: $vm.requestedScopes)

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

/// Multi-select list of scopes for the `requestedScopes` parameter that the
/// prompt APIs accept. Selecting nothing omits the parameter entirely.
private struct ScopeMultiSelect: View {
  @Binding var selection: Set<TokenScope>
  @State private var isExpanded: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Requested Scopes")
        .font(.subheadline)
        .fontWeight(.medium)

      DisclosureGroup(isExpanded: $isExpanded) {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(TokenScope.allCases, id: \.rawValue) { scope in
            Toggle(scope.rawValue, isOn: binding(for: scope))
              .font(.caption)
              .padding(.vertical, 6)
          }
        }
      } label: {
        Text(summary)
          .font(.caption)
          .foregroundColor(selection.isEmpty ? .secondary : .primary)
      }
      .padding()
      .background(Color(.systemBackground))
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color(.systemGray4), lineWidth: 1)
      )
    }
  }

  private var summary: String {
    guard !selection.isEmpty else { return "None — parameter omitted" }
    return orderedSelection(selection).map(\.rawValue).joined(separator: ", ")
  }

  private func binding(for scope: TokenScope) -> Binding<Bool> {
    Binding(
      get: { selection.contains(scope) },
      set: { isOn in
        if isOn {
          selection.insert(scope)
        } else {
          selection.remove(scope)
        }
      }
    )
  }
}

/// Sorts a scope selection into declaration order so the value sent over the
/// bridge does not depend on `Set` iteration order.
private func orderedSelection(_ selection: Set<TokenScope>) -> [TokenScope] {
  TokenScope.allCases.filter { selection.contains($0) }
}

@MainActor
final class StepUpAuthViewModel: ObservableObject {
  @Published var scope: TokenScope?
  @Published var requestedScopes: Set<TokenScope> = []
  @Published var isCheckingRequired: Bool = false
  @Published var isPrompting: Bool = false
  @Published var isPromptingMfa: Bool = false
  @Published var isPromptingReauth: Bool = false
  @Published var resultMessage: String?
  @Published var errorMessage: String?

  private let sdk = DynamicSDK.instance()

  func checkStepUpRequired() async {
    guard let scope else { return }
    isCheckingRequired = true
    resultMessage = nil
    errorMessage = nil
    defer { isCheckingRequired = false }
    do {
      let required = try await sdk.stepUpAuth.isStepUpRequired(scope: scope)
      resultMessage = "Step-up required for \"\(scope.rawValue)\": \(required)"
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

  private func scopesArray() -> [TokenScope]? {
    guard !requestedScopes.isEmpty else { return nil }
    return orderedSelection(requestedScopes)
  }
}
