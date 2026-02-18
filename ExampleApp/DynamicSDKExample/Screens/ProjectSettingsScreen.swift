import SwiftUI
import DynamicSDKSwift

struct ProjectSettingsScreen: View {
  @StateObject private var vm = ProjectSettingsViewModel()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if vm.isLoading {
          HStack { Spacer(); ProgressView(); Spacer() }
            .padding(.top, 40)
        } else if let error = vm.errorMessage {
          VStack(spacing: 12) {
            ErrorMessageView(message: error)
            Button("Retry") { Task { await vm.loadSettings() } }
              .buttonStyle(.borderedProminent)
          }
          .padding(.horizontal)
        } else if let settings = vm.settings {
          settingsContent(settings)
        }

        if let json = vm.rawJson {
          ValueCard(
            title: "Raw JSON:",
            value: json,
            displayValue: String(json.prefix(200)) + "...",
            copyValue: json
          )
        }
      }
      .padding(.vertical)
    }
    .navigationTitle("Project Settings")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { Task { await vm.loadSettings() } }
    .refreshable { await vm.loadSettings() }
  }

  @ViewBuilder
  private func settingsContent(_ s: ProjectSettings) -> some View {
    // Environment
    SettingsSection(title: "Environment") {
      SettingsRow(label: "Name", value: s.environmentName?.rawValue ?? "N/A")
    }

    // General
    SettingsSection(title: "General") {
      SettingsRow(label: "Display Name", value: s.general.displayName ?? "N/A")
      SettingsRow(label: "Support Email", value: s.general.supportEmail ?? "N/A")
      SettingsRow(label: "App Logo", value: s.general.appLogo ?? "N/A")
      SettingsRow(label: "Email Company Name", value: s.general.emailCompanyName ?? "N/A")
      SettingsRow(label: "Skip Optional KYC", value: s.general.skipOptionalKYCFieldDuringOnboarding?.description ?? "N/A")
    }

    // Chains
    SettingsSection(title: "Chains (\(s.chains.count))") {
      ForEach(Array(s.chains.enumerated()), id: \.offset) { _, chain in
        HStack {
          Text(chain.name)
            .fontWeight(.medium)
          Spacer()
          Text(chain.enabled ? "Enabled" : "Disabled")
            .foregroundColor(chain.enabled ? .green : .red)
            .font(.caption)
            .fontWeight(.bold)
        }
        if let networks = chain.networks, !networks.isEmpty {
          ForEach(Array(networks.enumerated()), id: \.offset) { _, net in
            HStack {
              Text("  \(net.chainName)")
                .font(.caption)
                .foregroundColor(.secondary)
              Spacer()
              Text(net.enabled ? "On" : "Off")
                .font(.caption2)
                .foregroundColor(net.enabled ? .green : .red)
            }
          }
        }
      }
    }

    // Design
    SettingsSection(title: "Design") {
      if let modal = s.design.modal {
        SettingsRow(label: "Theme", value: modal.theme ?? "N/A")
        SettingsRow(label: "Primary Color", value: modal.primaryColor ?? "N/A")
        SettingsRow(label: "View", value: modal.view ?? "N/A")
        SettingsRow(label: "Template", value: modal.template ?? "N/A")
        SettingsRow(label: "Radius", value: modal.radius.map { String(format: "%.0f", $0) } ?? "N/A")
      } else {
        Text("No modal design settings").foregroundColor(.secondary).font(.caption)
      }
    }

    // Privacy
    SettingsSection(title: "Privacy") {
      SettingsRow(label: "Collect IP", value: s.privacy.collectIp?.description ?? "N/A")
    }

    // SDK Settings
    SettingsSection(title: "SDK") {
      SettingsRow(label: "Multi Wallet", value: s.sdk.multiWallet?.description ?? "N/A")
      SettingsRow(label: "Confirm Wallet Transfers", value: s.sdk.confirmWalletTransfers?.description ?? "N/A")
      SettingsRow(label: "Onramp Funding", value: s.sdk.onrampFunding?.description ?? "N/A")
      SettingsRow(label: "Passkey Embedded Wallet", value: s.sdk.passkeyEmbeddedWalletEnabled?.description ?? "N/A")
      SettingsRow(label: "Auto Embedded Wallet", value: s.sdk.automaticEmbeddedWalletCreation?.description ?? "N/A")
      SettingsRow(label: "Prevent Orphaned Accounts", value: s.sdk.preventOrphanedAccounts?.description ?? "N/A")
      SettingsRow(label: "Block Email Subaddresses", value: s.sdk.blockEmailSubaddresses?.description ?? "N/A")
      SettingsRow(label: "Show Fiat", value: s.sdk.showFiat?.description ?? "N/A")

      if let emailSignIn = s.sdk.emailSignIn {
        SettingsRow(label: "Email Sign-In Provider", value: emailSignIn.signInProvider?.rawValue ?? "N/A")
      }

      if let walletConnect = s.sdk.walletConnect {
        SettingsRow(label: "WalletConnect v2", value: walletConnect.v2Enabled?.description ?? "N/A")
      }

      if let embeddedWallets = s.sdk.embeddedWallets {
        SettingsRow(label: "Auto Create EW", value: embeddedWallets.automaticEmbeddedWalletCreation?.description ?? "N/A")
        SettingsRow(label: "Email Recovery", value: embeddedWallets.emailRecoveryEnabled?.description ?? "N/A")
        SettingsRow(label: "Tx Simulation", value: embeddedWallets.transactionSimulation?.description ?? "N/A")
        SettingsRow(label: "Default Wallet Version", value: embeddedWallets.defaultWalletVersion?.rawValue ?? "N/A")
      }
    }

    // WaaS
    if let waas = s.sdk.waas {
      SettingsSection(title: "WaaS") {
        SettingsRow(label: "Passcode Required", value: waas.passcodeRequired.description)
        SettingsRow(label: "Backup Options", value: waas.backupOptions.map(\.rawValue).joined(separator: ", "))
        SettingsRow(label: "Export Disabled", value: waas.exportDisabled?.description ?? "N/A")
        if let da = waas.delegatedAccess {
          SettingsRow(label: "Delegated Access", value: da.enabled?.description ?? "N/A")
          SettingsRow(label: "Requires Delegation", value: da.requiresDelegation?.description ?? "N/A")
        }
      }
    }

    // Security
    SettingsSection(title: "Security") {
      if let jwt = s.security.jwtDuration {
        SettingsRow(label: "JWT Duration", value: "\(jwt.amount) \(jwt.unit.rawValue)")
      }
      SettingsRow(label: "Environment Locked", value: s.security.environmentLocked?.description ?? "N/A")

      if let mfa = s.security.mfa {
        SettingsRow(label: "MFA Enabled", value: mfa.enabled?.description ?? "N/A")
        SettingsRow(label: "MFA Required", value: mfa.required?.description ?? "N/A")
      }

      if let ext = s.security.externalAuth {
        SettingsRow(label: "External Auth", value: ext.enabled?.description ?? "N/A")
        SettingsRow(label: "JWKS URL", value: ext.jwksUrl ?? "N/A")
      }
    }

    // Providers
    if let providers = s.providers, !providers.isEmpty {
      SettingsSection(title: "Providers (\(providers.count))") {
        ForEach(Array(providers.enumerated()), id: \.offset) { _, provider in
          HStack {
            Text(provider.provider.rawValue)
              .fontWeight(.medium)
            Spacer()
            if let id = provider.id {
              Text(String(id.prefix(8)) + "...")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
      }
    }

    // KYC Fields
    if !s.kyc.isEmpty {
      SettingsSection(title: "KYC Fields (\(s.kyc.count))") {
        ForEach(Array(s.kyc.enumerated()), id: \.offset) { _, field in
          HStack {
            Text(field.label ?? field.name)
              .fontWeight(.medium)
            Spacer()
            HStack(spacing: 4) {
              if field.required {
                Text("Required")
                  .font(.caption2)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(Color.red.opacity(0.2))
                  .cornerRadius(4)
              }
              Text(field.enabled ? "On" : "Off")
                .font(.caption2)
                .foregroundColor(field.enabled ? .green : .red)
            }
          }
        }
      }
    }

    // Networks
    if let networks = s.networks, !networks.isEmpty {
      SettingsSection(title: "Networks (\(networks.count))") {
        ForEach(Array(networks.enumerated()), id: \.offset) { _, netConfig in
          VStack(alignment: .leading, spacing: 4) {
            Text(netConfig.chainName ?? "Unknown Chain")
              .fontWeight(.bold)
              .font(.subheadline)
            if let nets = netConfig.networks {
              ForEach(Array(nets.enumerated()), id: \.offset) { _, net in
                HStack {
                  Text(net.name)
                    .font(.caption)
                  Spacer()
                  Text("ID: \(net.chainId)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                  if net.isTestnet == true {
                    Text("Testnet")
                      .font(.caption2)
                      .padding(.horizontal, 4)
                      .padding(.vertical, 1)
                      .background(Color.orange.opacity(0.2))
                      .cornerRadius(3)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

// MARK: - Helper Views

private struct SettingsSection<Content: View>: View {
  let title: String
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline)
        .fontWeight(.bold)
      Divider()
      content()
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
    .padding(.horizontal)
  }
}

private struct SettingsRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack {
      Text(label)
        .font(.subheadline)
        .foregroundColor(.secondary)
      Spacer()
      Text(value)
        .font(.subheadline)
        .fontWeight(.medium)
        .multilineTextAlignment(.trailing)
        .lineLimit(2)
    }
  }
}

// MARK: - ViewModel

@MainActor
final class ProjectSettingsViewModel: ObservableObject {
  @Published var settings: ProjectSettings?
  @Published var rawJson: String?
  @Published var isLoading = false
  @Published var errorMessage: String?

  private let sdk = DynamicSDK.instance()

  func loadSettings() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let result = try await sdk.auth.getProjectSettings()
      settings = result

      if let result = result {
        let data = try JSONEncoder().encode(result)
        if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
          let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
          rawJson = String(data: prettyData, encoding: .utf8)
        }
      }
    } catch {
      errorMessage = "Failed to load project settings: \(error.localizedDescription)"
    }
  }
}
