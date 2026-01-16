import SwiftUI
import DynamicSDKSwift

struct WalletDetailsScreen: View {
  let wallet: BaseWallet
  @Environment(\.colorScheme) var colorScheme
  @State private var showCopiedAlert = false
  @State private var feedbackLabel: String?
  @StateObject private var vm: WalletDetailsViewModel
  
  init(wallet: BaseWallet) {
    self.wallet = wallet
    self._vm = StateObject(wrappedValue: WalletDetailsViewModel(wallet: wallet))
  }
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        // Wallet Card
        WalletDetailCard(
          wallet: wallet,
          balance: vm.balance,
          network: vm.networkDescription,
          isLoadingBalance: vm.isLoadingBalance,
          isLoadingNetwork: vm.isLoadingNetwork
        )
        
        // Feedback message
        if let feedback = feedbackLabel {
          Text(feedback)
            .font(.caption)
            .foregroundColor(.orange)
            .padding(.horizontal)
        }
        
        // Copy Address Button
        Button(action: {
          UIPasteboard.general.string = wallet.address
          showCopiedAlert = true
        }) {
          HStack {
            Image(systemName: "doc.on.doc")
            Text("Copy Address")
            Spacer()
          }
          .padding()
          .frame(maxWidth: .infinity)
          .background(Color.blue.opacity(0.1))
          .foregroundColor(.blue)
          .cornerRadius(8)
        }
        .padding(.horizontal)
        
        // Sign Message Button (for all chains)
        NavigationLink(destination: SignMessageScreen(wallet: wallet)) {
          HStack {
            Image(systemName: "pencil.circle")
            Text("Sign Message")
            Spacer()
            Image(systemName: "chevron.right")
          }
          .padding()
          .frame(maxWidth: .infinity)
          .background(Color.blue.opacity(0.1))
          .foregroundColor(.blue)
          .cornerRadius(8)
        }
        .padding(.horizontal)
        
        if let err = vm.errorMessage {
          ErrorMessageView(message: err)
            .padding(.horizontal)
        }

        if wallet.id != nil {
          Button(action: { vm.setPrimary() }) {
            HStack {
              Image(systemName: "star.fill")
              Text("Set as Primary Wallet")
              Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(8)
          }
          .padding(.horizontal)
        }

        NavigationLink(destination: SwitchNetworkScreen(wallet: wallet)) {
          HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
            Text("Switch Network")
            Spacer()
            Image(systemName: "chevron.right")
          }
          .padding()
          .frame(maxWidth: .infinity)
          .background(Color.blue.opacity(0.1))
          .foregroundColor(.blue)
          .cornerRadius(8)
        }
        .padding(.horizontal)

        // Chain-specific actions
        if wallet.chain.uppercased() == "EVM" {
          EVMActionsView(wallet: wallet)
        } else if wallet.chain.uppercased() == "SOL" {
          SolanaActionsView(wallet: wallet)
        }
        
        Spacer()
      }
      .padding(.vertical)
    }
    .navigationTitle("Wallet Details")
    .navigationBarTitleDisplayMode(.inline)
    .alert("Copied to clipboard", isPresented: $showCopiedAlert) {
      Button("OK", role: .cancel) {}
    }
    .onAppear { vm.refresh() }
  }
}

struct WalletDetailCard: View {
  let wallet: BaseWallet
  let balance: String?
  let network: String?
  let isLoadingBalance: Bool
  let isLoadingNetwork: Bool
  @Environment(\.colorScheme) var colorScheme
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          if let walletName = wallet.walletName {
            Text(walletName)
              .font(.headline)
              .foregroundColor(colorScheme == .dark ? .white : .black)
          }
          Text(wallet.chain.uppercased())
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.2))
            .foregroundColor(.blue)
            .cornerRadius(4)
        }
        Spacer()
      }
      
      Text("Address")
        .font(.caption)
        .foregroundColor(.secondary)
      
      Text(wallet.address)
        .font(.system(.caption, design: .monospaced))
        .foregroundColor(colorScheme == .dark ? .white : .black)
        .lineLimit(2)
        .truncationMode(.middle)

      Divider().opacity(0.3)
      Text("Current Network")
        .font(.caption)
        .foregroundColor(.secondary)
      if let network, !network.isEmpty {
        Text(network)
          .font(.system(.caption2, design: .monospaced))
          .foregroundColor(colorScheme == .dark ? .white : .black)
          .lineLimit(2)
          .truncationMode(.middle)
      } else if isLoadingNetwork {
        HStack(spacing: 8) {
          ProgressView().scaleEffect(0.9)
          Text("Loading…")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      } else {
        Text("-")
          .font(.caption2)
          .foregroundColor(.secondary)
      }

      Divider().opacity(0.3)
      Text("Balance")
        .font(.caption)
        .foregroundColor(.secondary)
      if let balance, !balance.isEmpty {
        Text(balance)
          .font(.system(.caption2, design: .monospaced))
          .foregroundColor(colorScheme == .dark ? .white : .black)
          .lineLimit(2)
          .truncationMode(.middle)
      } else if isLoadingBalance {
        HStack(spacing: 8) {
          ProgressView().scaleEffect(0.9)
          Text("Loading…")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      } else {
        Text("-")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
    }
    .padding()
    .background(Color(.systemBackground).opacity(0.8))
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color(.systemGray4), lineWidth: 1)
    )
    .padding(.horizontal)
  }
}

struct EVMActionsView: View {
  let wallet: BaseWallet
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("EVM Actions")
        .font(.title2)
        .fontWeight(.bold)
        .padding(.horizontal)
      
      // Sign Transaction
      NavigationLink(destination: EvmSignTransactionScreen(wallet: wallet)) {
        ActionButton(
          icon: "signature",
          title: "Sign Transaction"
        )
      }
      .padding(.horizontal)
      
      // Sign Typed Data
      NavigationLink(destination: EvmSignTypedDataScreen(wallet: wallet)) {
        ActionButton(
          icon: "doc.text",
          title: "Sign Typed Data"
        )
      }
      .padding(.horizontal)
      
      // Send Transaction
      NavigationLink(destination: EvmSendTransactionScreen(wallet: wallet)) {
        ActionButton(
          icon: "paperplane.fill",
          title: "Send Transaction"
        )
      }
      .padding(.horizontal)

      // Send ERC20
      NavigationLink(destination: EvmSendErc20Screen(wallet: wallet)) {
        ActionButton(
          icon: "arrow.right.arrow.left",
          title: "Send ERC20"
        )
      }
      .padding(.horizontal)
      
      // Write Contract
      NavigationLink(destination: EvmWriteContractScreen(wallet: wallet)) {
        ActionButton(
          icon: "doc.plaintext",
          title: "Write Contract"
        )
      }
      .padding(.horizontal)
    }
    .padding(.vertical)
  }
}

struct SolanaActionsView: View {
  let wallet: BaseWallet
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Solana Actions")
        .font(.title2)
        .fontWeight(.bold)
        .padding(.horizontal)
      
      // Sign Message (Solana specific)
      NavigationLink(destination: SolanaSignMessageScreen(wallet: wallet)) {
        ActionButton(
          icon: "pencil.circle",
          title: "Sign Message (Solana)"
        )
      }
      .padding(.horizontal)
      
      // Sign Transaction
      NavigationLink(destination: SolanaSignTransactionScreen(wallet: wallet)) {
        ActionButton(
          icon: "signature",
          title: "Sign Transaction"
        )
      }
      .padding(.horizontal)
      
      // Send Transaction
      NavigationLink(destination: SolanaSendTransactionScreen(wallet: wallet)) {
        ActionButton(
          icon: "paperplane.fill",
          title: "Send Transaction"
        )
      }
      .padding(.horizontal)
    }
    .padding(.vertical)
  }
}

struct ActionButton: View {
  let icon: String
  let title: String
  
  var body: some View {
    HStack {
      Image(systemName: icon)
      Text(title)
      Spacer()
      Image(systemName: "chevron.right")
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(Color.blue.opacity(0.1))
    .foregroundColor(.blue)
    .cornerRadius(8)
  }
}

