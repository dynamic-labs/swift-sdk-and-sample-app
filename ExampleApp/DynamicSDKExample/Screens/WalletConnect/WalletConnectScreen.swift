import SwiftUI
import Combine
import DynamicSDKSwift

struct WalletConnectScreen: View {
  @State private var uriText = ""
  @State private var isPairing = false
  @State private var error: String?
  @State private var sessions: [String: WcSession] = [:]
  @State private var cancellables = Set<AnyCancellable>()
  @State private var showScanner = false

  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(spacing: 12) {
        // Scan QR button
        Button {
          showScanner = true
        } label: {
          HStack {
            Image(systemName: "qrcode.viewfinder")
            Text("Scan QR Code")
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .background(Color(.systemGray5))
          .foregroundColor(.primary)
          .cornerRadius(8)
        }

        // Divider
        HStack {
          Rectangle().frame(height: 1).foregroundColor(Color(.separator))
          Text("or paste URI")
            .font(.caption)
            .foregroundColor(.secondary)
          Rectangle().frame(height: 1).foregroundColor(Color(.separator))
        }

        // Pair section
        TextField("wc:...", text: $uriText)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .autocapitalization(.none)
          .disableAutocorrection(true)

        Button(action: pair) {
          HStack {
            if isPairing {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
              Text("Pair")
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .background(Color.blue)
          .foregroundColor(.white)
          .cornerRadius(8)
        }
        .disabled(isPairing || uriText.trimmingCharacters(in: .whitespaces).isEmpty)

        if let error = error {
          Text(error)
            .foregroundColor(.red)
            .font(.caption)
        }
      }
      .padding()

      Divider()

      // Sessions section
      Text("Active Sessions")
        .font(.title2)
        .fontWeight(.bold)
        .padding(.horizontal)
        .padding(.top, 16)

      if sessions.isEmpty {
        VStack(spacing: 8) {
          Spacer()
          Image(systemName: "link.badge.plus")
            .font(.system(size: 48))
            .foregroundColor(.secondary)
          Text("No active sessions")
            .foregroundColor(.secondary)
          Text("Scan a QR code or paste a URI to connect")
            .font(.caption)
            .foregroundColor(.secondary.opacity(0.7))
          Spacer()
        }
        .frame(maxWidth: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 8) {
            ForEach(Array(sessions.keys.sorted()), id: \.self) { topic in
              if let session = sessions[topic] {
                SessionCard(session: session) {
                  disconnect(topic: topic)
                }
              }
            }
          }
          .padding(.horizontal)
          .padding(.top, 8)
        }
      }
    }
    .navigationTitle("WalletConnect")
    .fullScreenCover(isPresented: $showScanner) {
      QrScannerView(
        onScanned: { scannedUri in
          showScanner = false
          uriText = scannedUri
          pair()
        },
        onDismiss: { showScanner = false }
      )
    }
    .onAppear {
      guard let sdk = try? DynamicSDK.getInstance() else { return }
      let wc = sdk.walletConnect
      sessions = wc.sessions
      wc.sessionsChanges
        .receive(on: DispatchQueue.main)
        .sink { sessions = $0 }
        .store(in: &cancellables)
    }
  }

  private func pair() {
    let uri = uriText.trimmingCharacters(in: .whitespaces)
    guard !uri.isEmpty else { return }

    isPairing = true
    error = nil

    Task {
      do {
        let wc = try DynamicSDK.getInstance().walletConnect
        try await wc.pair(uri: uri)
        await MainActor.run {
          uriText = ""
          isPairing = false
        }
      } catch {
        await MainActor.run {
          self.error = "Pairing failed: \(error.localizedDescription)"
          isPairing = false
        }
      }
    }
  }

  private func disconnect(topic: String) {
    Task {
      do {
        let wc = try DynamicSDK.getInstance().walletConnect
        try await wc.disconnectSession(topic: topic)
      } catch {
        await MainActor.run {
          self.error = "Disconnect failed: \(error.localizedDescription)"
        }
      }
    }
  }
}

private struct SessionCard: View {
  let session: WcSession
  let onDisconnect: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(session.peer.name)
            .fontWeight(.bold)
          if !session.peer.url.isEmpty {
            Text(session.peer.url)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        Spacer()
        Button(action: onDisconnect) {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.red)
            .font(.title3)
        }
      }

      if !session.namespaces.isEmpty {
        HStack(spacing: 4) {
          ForEach(Array(session.namespaces.keys.sorted()), id: \.self) { ns in
            Text(ns)
              .font(.caption2)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.blue.opacity(0.1))
              .cornerRadius(12)
          }
        }
      }

      Text("Topic: \(String(session.topic.prefix(12)))...")
        .font(.caption2)
        .foregroundColor(.secondary.opacity(0.6))
        .monospaced()
    }
    .padding(12)
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
}
