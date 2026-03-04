import SwiftUI
import DynamicSDKSwift
import Combine

struct DelegationScreen: View {
    @StateObject private var viewModel = DelegationViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Feedback Message
                if let message = viewModel.feedbackMessage {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // State Info Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Delegation State")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Divider()
                    
                    InfoRow(
                        label: "Delegation Enabled",
                        value: viewModel.delegationState?.delegatedAccessEnabled?.description ?? "N/A"
                    )
                    InfoRow(
                        label: "Delegation Required",
                        value: viewModel.delegationState?.requiresDelegation?.description ?? "N/A"
                    )
                    InfoRow(
                        label: "Wallets Count",
                        value: "\(viewModel.delegationState?.walletsDelegatedStatus.count ?? 0)"
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Actions Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Actions")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    ActionButton(
                        title: "Open Delegation Modal",
                        icon: "arrow.up.forward.square",
                        action: viewModel.initDelegationProcess
                    )
                    ActionButton(
                        title: "Check Should Prompt",
                        icon: "questionmark.circle",
                        action: viewModel.checkShouldPrompt
                    )
                    ActionButton(
                        title: "Get Wallets Status",
                        icon: "arrow.clockwise",
                        action: viewModel.getWalletsStatus
                    )
                    ActionButton(
                        title: "Delegate All Wallets",
                        icon: "shield",
                        action: viewModel.delegateAllWallets
                    )
                    ActionButton(
                        title: "Dismiss All Prompts",
                        icon: "xmark.circle",
                        action: viewModel.dismissAllPrompts
                    )
                    ActionButton(
                        title: "Clear Session State",
                        icon: "trash",
                        action: viewModel.clearSessionState
                    )
                }
                
                // Wallets List
                if let wallets = viewModel.delegationState?.walletsDelegatedStatus, !wallets.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Wallets")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        ForEach(wallets, id: \.id) { wallet in
                            WalletDelegationCard(
                                wallet: wallet,
                                onRevoke: { viewModel.revokeWallet(wallet) },
                                onDeny: { viewModel.denyWallet(wallet) },
                                onDismiss: { viewModel.dismissPrompt(walletId: wallet.id) }
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Wallet Delegation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadDelegationState()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
    }
}

struct InfoRow: View {
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
                .fontWeight(.bold)
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(8)
        }
    }
}

struct WalletDelegationCard: View {
    let wallet: WalletDelegatedStatus
    let onRevoke: () -> Void
    let onDeny: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: getStatusIcon(wallet.status))
                    .foregroundColor(getStatusColor(wallet.status))
                
                Text("\(wallet.address.prefix(10))...\(wallet.address.suffix(8))")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(wallet.status.rawValue.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(getStatusColor(wallet.status).opacity(0.2))
                    .foregroundColor(getStatusColor(wallet.status))
                    .cornerRadius(12)
            }
            
            Text("Chain: \(wallet.chain)")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("ID: \(wallet.id)")
                .font(.caption)
                .foregroundColor(.secondary)
            if let dismissed = wallet.isDismissedThisSession {
                Text("Dismissed: \(dismissed.description)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 8) {
                switch wallet.status {
                case .delegated:
                    Button(action: onRevoke) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Revoke")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    
                case .pending:
                    Button(action: onDeny) {
                        HStack {
                            Image(systemName: "hand.raised")
                            Text("Deny")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: onDismiss) {
                        HStack {
                            Image(systemName: "minus.circle")
                            Text("Dismiss")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    
                default:
                    EmptyView()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func getStatusIcon(_ status: DelegationStatus) -> String {
        switch status {
        case .delegated:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .pending:
            return "clock.fill"
        }
    }
    
    private func getStatusColor(_ status: DelegationStatus) -> Color {
        switch status {
        case .delegated:
            return .green
        case .denied:
            return .red
        case .pending:
            return .orange
        }
    }
}

@MainActor
class DelegationViewModel: ObservableObject {
    private let sdk = DynamicSDK.shared
    
    @Published var delegationState: DelegatedAccessState?
    @Published var isLoading = false
    @Published var feedbackMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        observeDelegationChanges()
    }
    
    func loadDelegationState() {
        guard let sdk = sdk else { return }
        delegationState = sdk.wallets.delegatedAccessState
    }
    
    private func observeDelegationChanges() {
        guard let sdk = sdk else { return }
        sdk.wallets.delegatedAccessChanges
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.delegationState = state
            }
            .store(in: &cancellables)
    }
    
    func initDelegationProcess() {
        isLoading = true
        Task {
            do {
                guard let sdk = sdk else { 
                    await MainActor.run {
                        feedbackMessage = "SDK not initialized"
                        isLoading = false
                    }
                    return
                }
                try await sdk.wallets.waas.delegation.initDelegationProcess()
                await MainActor.run {
                    feedbackMessage = "Delegation modal opened"
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    feedbackMessage = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    func checkShouldPrompt() {
        isLoading = true
        Task {
            do {
                guard let sdk = sdk else {
                    await MainActor.run {
                        feedbackMessage = "SDK not initialized"
                        isLoading = false
                    }
                    return
                }
                let shouldPrompt = try await sdk.wallets.waas.delegation.shouldPromptWalletDelegation()
                await MainActor.run {
                    feedbackMessage = "Should prompt: \(shouldPrompt)"
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    feedbackMessage = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    func getWalletsStatus() {
        isLoading = true
        Task {
            do {
                guard let sdk = sdk else {
                    await MainActor.run {
                        feedbackMessage = "SDK not initialized"
                        isLoading = false
                    }
                    return
                }
                let statuses = try await sdk.wallets.waas.delegation.getWalletsDelegatedStatus()
                await MainActor.run {
                    feedbackMessage = "Found \(statuses.count) wallets"
                    loadDelegationState()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    feedbackMessage = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    func delegateAllWallets() {
        isLoading = true
        Task {
            do {
                guard let sdk = sdk else {
                    await MainActor.run {
                        feedbackMessage = "SDK not initialized"
                        isLoading = false
                    }
                    return
                }
                try await sdk.wallets.waas.delegation.delegateKeyShares()
                await MainActor.run {
                    feedbackMessage = "Delegation started for all wallets"
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    feedbackMessage = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    func revokeWallet(_ wallet: WalletDelegatedStatus) {
        isLoading = true
        Task {
            do {
                guard let sdk = sdk else {
                    await MainActor.run {
                        feedbackMessage = "SDK not initialized"
                        isLoading = false
                    }
                    return
                }
                guard let chainEnum = ChainEnum.fromString(wallet.chain) else {
                    throw NSError(domain: "Invalid chain", code: -1)
                }
                
                try await sdk.wallets.waas.delegation.revokeDelegation(
                    wallets: [
                        DelegationWalletIdentifier(
                            chainName: chainEnum,
                            accountAddress: wallet.address
                        )
                    ]
                )
                await MainActor.run {
                    feedbackMessage = "Revoked delegation for \(wallet.address)"
                    loadDelegationState()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    feedbackMessage = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    func denyWallet(_ wallet: WalletDelegatedStatus) {
        isLoading = true
        Task {
            do {
                guard let sdk = sdk else {
                    await MainActor.run {
                        feedbackMessage = "SDK not initialized"
                        isLoading = false
                    }
                    return
                }
                try await sdk.wallets.waas.delegation.denyWalletDelegation(walletId: wallet.id)
                await MainActor.run {
                    feedbackMessage = "Denied delegation for \(wallet.address)"
                    loadDelegationState()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    feedbackMessage = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    func dismissPrompt(walletId: String) {
        isLoading = true
        Task {
            do {
                guard let sdk = sdk else {
                    await MainActor.run {
                        feedbackMessage = "SDK not initialized"
                        isLoading = false
                    }
                    return
                }
                try await sdk.wallets.waas.delegation.dismissDelegationPrompt(walletId: walletId)
                await MainActor.run {
                    feedbackMessage = "Dismissed prompt for wallet"
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    feedbackMessage = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    func dismissAllPrompts() {
        isLoading = true
        Task {
            do {
                guard let sdk = sdk else {
                    await MainActor.run {
                        feedbackMessage = "SDK not initialized"
                        isLoading = false
                    }
                    return
                }
                try await sdk.wallets.waas.delegation.dismissDelegationPrompt()
                await MainActor.run {
                    feedbackMessage = "Dismissed all prompts"
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    feedbackMessage = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    func clearSessionState() {
        isLoading = true
        Task {
            do {
                guard let sdk = sdk else {
                    await MainActor.run {
                        feedbackMessage = "SDK not initialized"
                        isLoading = false
                    }
                    return
                }
                try await sdk.wallets.waas.delegation.clearDelegationSessionState()
                await MainActor.run {
                    feedbackMessage = "Session state cleared"
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    feedbackMessage = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}
