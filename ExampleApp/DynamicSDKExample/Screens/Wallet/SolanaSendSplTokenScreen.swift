import SwiftUI
import DynamicSDKSwift
import SolanaWeb3

// MARK: - View Model

@MainActor
final class SolanaSendSplTokenViewModel: ObservableObject {
  let wallet: BaseWallet

  @Published var tokens: [TokenBalance] = []
  @Published var selectedToken: TokenBalance?
  @Published var amount: String = ""
  @Published var recipient: String = ""
  @Published var isLoadingTokens = false
  @Published var isSending = false
  @Published var errorMessage: String?
  @Published var txSignature: String?
  @Published var showTokenPicker = false

  init(wallet: BaseWallet) {
    self.wallet = wallet
  }

  var selectedTokenDisplay: String {
    guard let token = selectedToken else { return "Select token" }
    let symbol = token.symbol ?? "Unknown"
    let balance = token.balanceDecimal ?? token.balance
    return "\(symbol)  \(balance)"
  }

  var availableBalance: String? {
    guard let token = selectedToken else { return nil }
    return token.balanceDecimal ?? token.balance
  }

  func loadTokens() async {
    isLoadingTokens = true
    errorMessage = nil

    do {
      let sdk = DynamicSDK.instance()
      let solanaNetworks = sdk.networks.solana

      guard !solanaNetworks.isEmpty else {
        errorMessage = "No Solana networks configured.\n\nThe SDK has not emitted any Solana network configurations. Ensure your Dynamic dashboard has Solana enabled and the WebView has fully initialized."
        isLoadingTokens = false
        return
      }

      let networkIds: [Int] = solanaNetworks.compactMap { network in
        if let intVal = network.networkId.value as? Int { return intVal }
        if let intVal = network.networkId.value as? Int64 { return Int(intVal) }
        if let strVal = network.networkId.value as? String { return Int(strVal) }
        return nil
      }

      guard !networkIds.isEmpty else {
        errorMessage = "Could not resolve Solana network IDs.\n\nRaw networkId values: \(solanaNetworks.map { "\($0.networkId.value)" }.joined(separator: ", "))"
        isLoadingTokens = false
        return
      }

      let request = MultichainBalanceRequest(
        balanceRequests: [
          BalanceRequestItem(
            address: wallet.address,
            chain: .sol,
            networkIds: networkIds
          )
        ],
        filterSpamTokens: true
      )

      let response = try await sdk.wallets.getMultichainBalances(balanceRequest: request)

      // Filter to only SPL tokens (non-native, with a contract address, non-zero balance)
      tokens = response.balances.filter { balance in
        guard balance.isNative != true else { return false }
        guard let addr = balance.contractAddress, !addr.isEmpty else { return false }
        let bal = Double(balance.balanceDecimal ?? balance.balance) ?? 0
        return bal > 0
      }.sorted { a, b in
        (a.symbol ?? "") < (b.symbol ?? "")
      }

      // Also include native SOL for reference if it has balance
      let nativeTokens = response.balances.filter { $0.isNative == true }
      if !nativeTokens.isEmpty {
        tokens = nativeTokens + tokens
      }

    } catch {
      errorMessage = "Failed to load token balances.\n\n\(String(describing: error))\n\nLocalized: \(error.localizedDescription)"
    }

    isLoadingTokens = false
  }

  func selectToken(_ token: TokenBalance) {
    selectedToken = token
    showTokenPicker = false
    amount = ""
    txSignature = nil
    errorMessage = nil
  }

  func setMaxAmount() {
    guard let token = selectedToken else { return }
    amount = token.balanceDecimal ?? token.balance
  }

  func send() {
    guard let token = selectedToken else {
      errorMessage = "Please select a token."
      return
    }

    guard token.isNative != true else {
      errorMessage = "Native SOL transfers are not supported here. Use the Send Transaction screen for native SOL."
      return
    }

    guard let mintAddress = token.contractAddress, !mintAddress.isEmpty else {
      errorMessage = "Selected token has no mint address.\n\nToken data: symbol=\(token.symbol ?? "nil"), name=\(token.name ?? "nil"), contractAddress=\(token.contractAddress ?? "nil")"
      return
    }

    let recipientStr = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
    let amountStr = amount.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !recipientStr.isEmpty else {
      errorMessage = "Please enter a recipient address."
      return
    }

    guard !amountStr.isEmpty, let amountDouble = Double(amountStr.replacingOccurrences(of: ",", with: ".")), amountDouble > 0 else {
      errorMessage = "Please enter a valid amount greater than zero."
      return
    }

    let dec = token.decimals ?? 6

    isSending = true
    errorMessage = nil
    txSignature = nil

    Task {
      do {
        let sdk = DynamicSDK.instance()

        let fromPubkey = try PublicKey.fromBase58(wallet.address)
        let mintPubkey = try PublicKey.fromBase58(mintAddress)
        let toPubkey = try PublicKey.fromBase58(recipientStr)

        let baseUnits = try parseDecimalToBaseUnits(amountStr, decimals: dec)

        let sourceATA = try PublicKey.findAssociatedTokenAddress(
          wallet: fromPubkey,
          tokenMint: mintPubkey
        )
        let destATA = try PublicKey.findAssociatedTokenAddress(
          wallet: toPubkey,
          tokenMint: mintPubkey
        )

        let createAtaInstruction = AssociatedTokenProgram.createIdempotent(
          fundingAccount: fromPubkey,
          associatedTokenAccount: destATA.address,
          associatedTokenAccountOwner: toPubkey,
          tokenMint: mintPubkey
        )

        let transferInstruction = TokenProgram.transfer(
          source: sourceATA.address,
          destination: destATA.address,
          owner: fromPubkey,
          amount: baseUnits
        )

        let connection = try sdk.solana.createConnection()
        let blockhash = try await connection.getLatestBlockhash()

        let transaction = Transaction.v0(
          payer: fromPubkey,
          instructions: [createAtaInstruction, transferInstruction],
          recentBlockhash: blockhash.blockhash
        )

        let signer = sdk.solana.createSigner(wallet: wallet)
        let signature = try await signer.signAndSendEncodedTransaction(
          base64Transaction: transaction.serializeToBase64()
        )

        txSignature = signature
        isSending = false
      } catch {
        errorMessage = "Transaction failed.\n\n\(String(describing: error))\n\nLocalized: \(error.localizedDescription)"
        isSending = false
      }
    }
  }

  private func parseDecimalToBaseUnits(_ value: String, decimals: Int) throws -> UInt64 {
    let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: ",", with: ".")
    guard !cleaned.isEmpty else { throw DynamicSDKError.custom("Amount is empty") }

    let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count <= 2 else { throw DynamicSDKError.custom("Invalid amount format") }

    let wholePart = String(parts[0].isEmpty ? "0" : parts[0])
    let fracPartRaw = parts.count == 2 ? String(parts[1]) : ""

    guard wholePart.range(of: #"^\d+$"#, options: .regularExpression) != nil else {
      throw DynamicSDKError.custom("Invalid amount: '\(wholePart)' is not a valid number")
    }
    guard fracPartRaw.isEmpty || fracPartRaw.range(of: #"^\d+$"#, options: .regularExpression) != nil else {
      throw DynamicSDKError.custom("Invalid fractional part: '\(fracPartRaw)'")
    }

    let fracPadded: String
    if decimals == 0 {
      fracPadded = ""
    } else {
      let trimmedFrac = String(fracPartRaw.prefix(decimals))
      fracPadded = trimmedFrac.padding(toLength: decimals, withPad: "0", startingAt: 0)
    }

    let combined = wholePart + fracPadded
    guard let result = UInt64(combined) else {
      throw DynamicSDKError.custom("Amount too large to represent as UInt64: '\(combined)'")
    }
    return result
  }
}

// MARK: - Screen

struct SolanaSendSplTokenScreen: View {
  let wallet: BaseWallet
  @StateObject private var vm: SolanaSendSplTokenViewModel
  @Environment(\.colorScheme) var colorScheme

  init(wallet: BaseWallet) {
    self.wallet = wallet
    self._vm = StateObject(wrappedValue: SolanaSendSplTokenViewModel(wallet: wallet))
  }

  private var cardBackground: Color {
    colorScheme == .dark
      ? Color(white: 0.11)
      : .white
  }

  private var surfaceBackground: Color {
    colorScheme == .dark
      ? Color(white: 0.06)
      : Color(white: 0.965)
  }

  private var borderColor: Color {
    colorScheme == .dark
      ? Color(white: 0.18)
      : Color(white: 0.88)
  }

  private var subtleText: Color {
    colorScheme == .dark
      ? Color(white: 0.50)
      : Color(white: 0.45)
  }

  private var accentGreen: Color {
    Color(red: 0.15, green: 0.72, blue: 0.45)
  }

  var body: some View {
    ZStack {
      surfaceBackground.ignoresSafeArea()

      ScrollView {
        VStack(spacing: 0) {

          // Header
          VStack(spacing: 6) {
            Text("Send Token")
              .font(.system(size: 28, weight: .semibold, design: .default))
              .foregroundColor(.primary)
            Text(truncateAddress(wallet.address))
              .font(.system(size: 13, weight: .medium, design: .monospaced))
              .foregroundColor(subtleText)
          }
          .padding(.top, 24)
          .padding(.bottom, 28)

          // Token Selector
          VStack(spacing: 0) {
            sectionLabel("Asset")
            tokenSelector
          }
          .padding(.horizontal, 20)

          Spacer().frame(height: 20)

          // Amount
          VStack(spacing: 0) {
            sectionLabel("Amount")
            amountField
          }
          .padding(.horizontal, 20)

          Spacer().frame(height: 20)

          // Recipient
          VStack(spacing: 0) {
            sectionLabel("Recipient")
            recipientField
          }
          .padding(.horizontal, 20)

          Spacer().frame(height: 32)

          // Send Button
          sendButton
            .padding(.horizontal, 20)

          Spacer().frame(height: 24)

          // Error
          if let error = vm.errorMessage {
            errorCard(error)
              .padding(.horizontal, 20)
            Spacer().frame(height: 16)
          }

          // Success
          if let sig = vm.txSignature {
            successCard(sig)
              .padding(.horizontal, 20)
            Spacer().frame(height: 16)
          }

          Spacer().frame(height: 48)
        }
      }
    }
    .navigationTitle("Send SPL Token")
    .navigationBarTitleDisplayMode(.inline)
    .task { await vm.loadTokens() }
    .sheet(isPresented: $vm.showTokenPicker) {
      tokenPickerSheet
    }
  }

  // MARK: - Section Label

  private func sectionLabel(_ text: String) -> some View {
    HStack {
      Text(text.uppercased())
        .font(.system(size: 11, weight: .semibold, design: .default))
        .foregroundColor(subtleText)
        .kerning(1.2)
      Spacer()
    }
    .padding(.bottom, 8)
  }

  // MARK: - Token Selector

  private var tokenSelector: some View {
    Button(action: { vm.showTokenPicker = true }) {
      HStack(spacing: 12) {
        // Token icon placeholder
        if let token = vm.selectedToken {
          tokenIcon(token)
        } else {
          Circle()
            .fill(borderColor)
            .frame(width: 40, height: 40)
            .overlay(
              Image(systemName: "questionmark")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(subtleText)
            )
        }

        VStack(alignment: .leading, spacing: 2) {
          if let token = vm.selectedToken {
            Text(token.symbol ?? "Unknown")
              .font(.system(size: 17, weight: .semibold))
              .foregroundColor(.primary)
            Text(token.name ?? "")
              .font(.system(size: 13))
              .foregroundColor(subtleText)
              .lineLimit(1)
          } else {
            Text(vm.isLoadingTokens ? "Loading tokens..." : "Select a token")
              .font(.system(size: 17, weight: .medium))
              .foregroundColor(vm.isLoadingTokens ? subtleText : .primary)
          }
        }

        Spacer()

        if vm.isLoadingTokens {
          ProgressView()
            .scaleEffect(0.8)
        } else {
          Image(systemName: "chevron.down")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(subtleText)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(cardBackground)
      .cornerRadius(14)
      .overlay(
        RoundedRectangle(cornerRadius: 14)
          .stroke(borderColor, lineWidth: 1)
      )
    }
    .disabled(vm.isLoadingTokens)
  }

  // MARK: - Amount Field

  private var amountField: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        TextField("0.00", text: $vm.amount)
          .font(.system(size: 32, weight: .light, design: .monospaced))
          .foregroundColor(.primary)
          .keyboardType(.decimalPad)
          .minimumScaleFactor(0.6)

        Spacer()

        if vm.selectedToken != nil {
          Button(action: vm.setMaxAmount) {
            Text("MAX")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(accentGreen)
              .kerning(0.8)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(accentGreen.opacity(0.12))
              .cornerRadius(6)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 18)
      .background(cardBackground)
      .cornerRadius(14)
      .overlay(
        RoundedRectangle(cornerRadius: 14)
          .stroke(borderColor, lineWidth: 1)
      )

      // Balance indicator
      if let balance = vm.availableBalance, let token = vm.selectedToken, token.isNative != true {
        HStack {
          Text("Available: \(balance) \(token.symbol ?? "")")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(subtleText)
          Spacer()
          if let dec = token.decimals {
            Text("\(dec) decimals")
              .font(.system(size: 11, weight: .regular))
              .foregroundColor(subtleText.opacity(0.7))
          }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
      }
    }
  }

  // MARK: - Recipient Field

  private var recipientField: some View {
    HStack(spacing: 0) {
      Image(systemName: "person.crop.circle")
        .font(.system(size: 18))
        .foregroundColor(subtleText)
        .frame(width: 36)

      TextField("Wallet address", text: $vm.recipient)
        .font(.system(size: 15, weight: .regular, design: .monospaced))
        .foregroundColor(.primary)
        .autocapitalization(.none)
        .disableAutocorrection(true)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 16)
    .background(cardBackground)
    .cornerRadius(14)
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(borderColor, lineWidth: 1)
    )
  }

  // MARK: - Send Button

  private var sendButton: some View {
    Button(action: vm.send) {
      HStack(spacing: 10) {
        if vm.isSending {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .scaleEffect(0.85)
        }
        Text(vm.isSending ? "Confirming..." : "Send")
          .font(.system(size: 17, weight: .semibold))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 17)
      .background(
        vm.isSending
          ? Color.primary.opacity(0.4)
          : Color.primary
      )
      .foregroundColor(colorScheme == .dark ? .black : .white)
      .cornerRadius(14)
    }
    .disabled(vm.isSending)
  }

  // MARK: - Error Card

  private func errorCard(_ message: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 16))
          .foregroundColor(Color(red: 0.9, green: 0.25, blue: 0.2))
        Text("Error")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(Color(red: 0.9, green: 0.25, blue: 0.2))
        Spacer()
      }

      Text(message)
        .font(.system(size: 12, weight: .regular, design: .monospaced))
        .foregroundColor(Color(red: 0.85, green: 0.2, blue: 0.15))
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(red: 0.95, green: 0.22, blue: 0.17).opacity(0.08))
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color(red: 0.9, green: 0.25, blue: 0.2).opacity(0.25), lineWidth: 1)
    )
  }

  // MARK: - Success Card

  private func successCard(_ signature: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 16))
          .foregroundColor(accentGreen)
        Text("Transaction Sent")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(accentGreen)
        Spacer()
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("SIGNATURE")
          .font(.system(size: 10, weight: .semibold))
          .foregroundColor(accentGreen.opacity(0.7))
          .kerning(1)

        Text(signature)
          .font(.system(size: 12, weight: .regular, design: .monospaced))
          .foregroundColor(accentGreen)
          .textSelection(.enabled)
          .lineLimit(3)
      }

      Button(action: {
        UIPasteboard.general.string = signature
      }) {
        HStack(spacing: 6) {
          Image(systemName: "doc.on.doc")
            .font(.system(size: 12))
          Text("Copy Signature")
            .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(accentGreen)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(accentGreen.opacity(0.12))
        .cornerRadius(8)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(accentGreen.opacity(0.06))
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(accentGreen.opacity(0.2), lineWidth: 1)
    )
  }

  // MARK: - Token Picker Sheet

  private var tokenPickerSheet: some View {
    NavigationView {
      ZStack {
        surfaceBackground.ignoresSafeArea()

        if vm.tokens.isEmpty && !vm.isLoadingTokens {
          VStack(spacing: 16) {
            Image(systemName: "tray")
              .font(.system(size: 36, weight: .thin))
              .foregroundColor(subtleText)
            Text("No tokens found")
              .font(.system(size: 17, weight: .medium))
              .foregroundColor(subtleText)
            Text("This wallet has no SPL token balances.")
              .font(.system(size: 14))
              .foregroundColor(subtleText.opacity(0.7))
              .multilineTextAlignment(.center)

            Button(action: {
              Task { await vm.loadTokens() }
            }) {
              Text("Refresh")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(cardBackground)
                .cornerRadius(10)
                .overlay(
                  RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 1)
                )
            }
            .padding(.top, 8)
          }
          .padding()
        } else if vm.isLoadingTokens {
          VStack(spacing: 12) {
            ProgressView()
            Text("Loading balances...")
              .font(.system(size: 14, weight: .medium))
              .foregroundColor(subtleText)
          }
        } else {
          ScrollView {
            LazyVStack(spacing: 1) {
              ForEach(Array(vm.tokens.enumerated()), id: \.offset) { _, token in
                tokenRow(token)
              }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
          }
        }
      }
      .navigationTitle("Select Token")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Cancel") {
            vm.showTokenPicker = false
          }
          .font(.system(size: 15, weight: .medium))
        }
      }
    }
  }

  private func tokenRow(_ token: TokenBalance) -> some View {
    Button(action: { vm.selectToken(token) }) {
      HStack(spacing: 14) {
        tokenIcon(token)

        VStack(alignment: .leading, spacing: 3) {
          Text(token.symbol ?? "Unknown")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.primary)
          if let name = token.name, !name.isEmpty {
            Text(name)
              .font(.system(size: 13))
              .foregroundColor(subtleText)
              .lineLimit(1)
          }
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 3) {
          Text(formatBalance(token.balanceDecimal ?? token.balance))
            .font(.system(size: 16, weight: .medium, design: .monospaced))
            .foregroundColor(.primary)
          if token.isNative == true {
            Text("Native")
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(subtleText)
              .padding(.horizontal, 8)
              .padding(.vertical, 2)
              .background(borderColor)
              .cornerRadius(4)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(
        vm.selectedToken?.contractAddress == token.contractAddress && token.contractAddress != nil
          ? accentGreen.opacity(0.06)
          : cardBackground
      )
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(
            vm.selectedToken?.contractAddress == token.contractAddress && token.contractAddress != nil
              ? accentGreen.opacity(0.3)
              : borderColor,
            lineWidth: 1
          )
      )
    }
    .padding(.vertical, 2)
  }

  // MARK: - Helpers

  private func tokenIcon(_ token: TokenBalance) -> some View {
    ZStack {
      Circle()
        .fill(
          LinearGradient(
            colors: [
              colorForSymbol(token.symbol).opacity(0.15),
              colorForSymbol(token.symbol).opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: 40, height: 40)

      Text(String((token.symbol ?? "?").prefix(1)).uppercased())
        .font(.system(size: 16, weight: .bold))
        .foregroundColor(colorForSymbol(token.symbol))
    }
  }

  private func colorForSymbol(_ symbol: String?) -> Color {
    guard let s = symbol?.uppercased() else { return .gray }
    switch s {
    case "SOL": return Color(red: 0.56, green: 0.28, blue: 0.96)
    case "USDC": return Color(red: 0.16, green: 0.47, blue: 0.85)
    case "USDT": return Color(red: 0.16, green: 0.65, blue: 0.53)
    case "BONK": return Color(red: 0.95, green: 0.62, blue: 0.07)
    case "JUP": return Color(red: 0.30, green: 0.85, blue: 0.60)
    case "RAY": return Color(red: 0.38, green: 0.30, blue: 0.92)
    default:
      let hash = abs(s.hashValue)
      let hue = Double(hash % 360) / 360.0
      return Color(hue: hue, saturation: 0.55, brightness: 0.75)
    }
  }

  private func truncateAddress(_ address: String) -> String {
    guard address.count > 12 else { return address }
    return "\(address.prefix(6))...\(address.suffix(4))"
  }

  private func formatBalance(_ balance: String) -> String {
    guard let value = Double(balance) else { return balance }
    if value == 0 { return "0" }
    if value >= 1_000_000 {
      return String(format: "%.2fM", value / 1_000_000)
    }
    if value >= 1_000 {
      return String(format: "%.2fK", value / 1_000)
    }
    if value >= 1 {
      return String(format: "%.4f", value)
    }
    return String(format: "%.6f", value)
  }
}
