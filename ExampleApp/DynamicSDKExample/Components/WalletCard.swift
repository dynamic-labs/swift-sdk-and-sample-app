import SwiftUI
import DynamicSDKSwift
#if canImport(UIKit)
import UIKit
#endif

struct WalletCard: View {
  let wallet: BaseWallet
  @State private var showCopiedAlert = false
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          if let walletName = wallet.walletName {
            Text(walletName)
              .font(.headline)
              .foregroundColor(colorScheme == .dark ? .white : .black)
          } else {
            Text("Wallet")
              .font(.headline)
              .foregroundColor(colorScheme == .dark ? .white : .black)
          }

          Text(wallet.chain.uppercased())
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Spacer()
      }

      Text(wallet.address)
        .font(.system(.caption, design: .monospaced))
        .foregroundColor(colorScheme == .dark ? .white : .black)
        .lineLimit(1)
        .truncationMode(.middle)

      Button(action: {
        #if canImport(UIKit)
        UIPasteboard.general.string = wallet.address
        #endif
        showCopiedAlert = true
      }) {
        HStack {
          Image(systemName: "doc.on.doc")
          Text("Copy Address")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(8)
      }
    }
    .padding()
    .background(Color(.systemBackground).opacity(0.8))
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color(.systemGray4), lineWidth: 1)
    )
    .padding(.horizontal, 16)
    .alert("Copied to clipboard", isPresented: $showCopiedAlert) {
      Button("OK", role: .cancel) {}
    }
  }
}


