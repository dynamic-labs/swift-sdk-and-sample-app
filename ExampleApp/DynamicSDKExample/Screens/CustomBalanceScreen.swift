import SwiftUI
import DynamicSDKSwift

struct CustomBalanceScreen: View {
  let wallet: BaseWallet
  @Environment(\.colorScheme) var colorScheme
  @StateObject private var vm: CustomBalanceViewModel

  init(wallet: BaseWallet) {
    self.wallet = wallet
    self._vm = StateObject(wrappedValue: CustomBalanceViewModel(wallet: wallet))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        // Quick Select Section
        Text("Quick Select")
          .font(.headline)
          .padding(.horizontal)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(vm.predefinedTokens) { token in
              TokenChip(
                token: token,
                isSelected: vm.isTokenSelected(token),
                onTap: { vm.selectToken(token) }
              )
            }
          }
          .padding(.horizontal)
        }
        .frame(height: 80)

        // Contract Address Field
        VStack(alignment: .leading, spacing: 8) {
          Text("Contract Address")
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal)

          TextField("Enter token contract address", text: $vm.contractAddress)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .padding(.horizontal)
            .onChange(of: vm.contractAddress) { _ in
              vm.onInputChanged()
            }
        }

        // Network ID Field
        VStack(alignment: .leading, spacing: 8) {
          Text("Network ID")
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal)

          TextField("Enter network ID (e.g., 1 for Ethereum)", text: $vm.networkId)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .keyboardType(.numberPad)
            .padding(.horizontal)
            .onChange(of: vm.networkId) { _ in
              vm.onInputChanged()
            }
        }

        // Check Balance Button
        Button(action: {
          hideKeyboard()
          vm.checkBalance()
        }) {
          HStack {
            if vm.isLoading {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            Text(vm.isLoading ? "Checking..." : "Check Balance")
          }
          .frame(maxWidth: .infinity)
          .padding()
          .background(vm.isLoading ? Color.blue.opacity(0.6) : Color.blue)
          .foregroundColor(.white)
          .cornerRadius(12)
        }
        .disabled(vm.isLoading)
        .padding(.horizontal)

        // Error Message
        if let error = vm.errorMessage {
          HStack {
            Image(systemName: "exclamationmark.circle.fill")
              .foregroundColor(.red)
            Text(error)
              .foregroundColor(.red)
          }
          .padding()
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.red.opacity(0.1))
          .cornerRadius(12)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color.red.opacity(0.3), lineWidth: 1)
          )
          .padding(.horizontal)
        }

        // Result Card
        if let token = vm.result {
          ResultCard(token: token)
            .padding(.horizontal)
        }

        // No Balance Card
        if vm.result == nil && !vm.isLoading && vm.errorMessage == nil && !vm.contractAddress.isEmpty && vm.hasChecked {
          NoBalanceCard()
            .padding(.horizontal)
        }

        Spacer(minLength: 20)
      }
      .padding(.vertical)
    }
    .navigationTitle("Custom Balance")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
  }
}

// Token Chip Component
struct TokenChip: View {
  let token: PredefinedToken
  let isSelected: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 4) {
        Text(token.symbol)
          .font(.subheadline)
          .fontWeight(.bold)
          .foregroundColor(isSelected ? .blue : .primary)

        Text(token.networkName)
          .font(.caption2)
          .foregroundColor(isSelected ? .blue : .secondary)
          .lineLimit(2)
          .multilineTextAlignment(.center)
      }
      .frame(width: 100, height: 70)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
}

// Result Card Component
struct ResultCard: View {
  let token: TokenBalance
  @Environment(\.colorScheme) var colorScheme

  var displayBalance: String {
    token.balanceDecimal ?? token.balance
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: "checkmark.circle.fill")
          .foregroundColor(Color(red: 0.18, green: 0.49, blue: 0.20))
          .font(.title2)

        Text("\(displayBalance) \(token.symbol ?? "tokens")")
          .font(.title2)
          .fontWeight(.bold)
          .foregroundColor(Color(red: 0.11, green: 0.37, blue: 0.13))
      }

      if let name = token.name {
        Text(name)
          .font(.subheadline)
          .foregroundColor(Color(red: 0.18, green: 0.49, blue: 0.20))
      }

      if let networkId = token.networkId {
        Text("Network ID: \(networkId)")
          .font(.caption)
          .foregroundColor(Color(red: 0.22, green: 0.56, blue: 0.24))
      }

      if let address = token.contractAddress {
        Text("Contract: \(String(address.prefix(10)))...\(String(address.suffix(8)))")
          .font(.caption)
          .monospaced()
          .foregroundColor(Color(red: 0.22, green: 0.56, blue: 0.24))
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(red: 0.91, green: 0.96, blue: 0.91))
    .cornerRadius(12)
  }
}

// No Balance Card Component
struct NoBalanceCard: View {
  var body: some View {
    HStack {
      Image(systemName: "info.circle.fill")
        .foregroundColor(.secondary)

      Text("0 tokens (no balance found)")
        .foregroundColor(.secondary)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
}
