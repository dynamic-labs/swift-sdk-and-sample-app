import SwiftUI
import DynamicSDKSwift
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit
#endif

// Add MFA Device screen (Flutter example parity: setup -> generate secret -> verify).
struct MfaAddDeviceScreen: View {
  enum Step { case setup, verify }

  let onFinished: () -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var step: Step = .setup
  @State private var deviceInfo: MfaAddDevice?
  @State private var code: String = ""
  @State private var isLoading: Bool = false
  @State private var alertTitle: String?
  @State private var alertMessage: String?

  private let sdk = DynamicSDK.instance()
  private let ciContext = CIContext()
  private let qrFilter = CIFilter.qrCodeGenerator()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if step == .setup {
          setupStep
        } else {
          verifyStep
        }
      }
      .padding(16)
    }
    .navigationTitle("Add MFA Device")
    .alert(alertTitle ?? "", isPresented: Binding(get: { alertTitle != nil }, set: { _ in alertTitle = nil; alertMessage = nil })) {
      Button("OK", role: .cancel) {
        if alertTitle == "Success" {
          onFinished()
          dismiss()
        }
      }
    } message: {
      Text(alertMessage ?? "")
    }
  }

  private var setupStep: some View {
    CardContainer {
      VStack(alignment: .leading, spacing: 12) {
        Text("Set up Authenticator App")
          .font(.headline)
          .fontWeight(.bold)

        Text("You'll need an authenticator app like Google Authenticator, Authy, or 1Password to generate verification codes.")
          .foregroundColor(.secondary)
          .font(.subheadline)

        Text("Steps:")
          .fontWeight(.bold)

        VStack(alignment: .leading, spacing: 4) {
          Text("1. Install an authenticator app on your device").foregroundColor(.secondary).font(.footnote)
          Text("2. Copy the secret code").foregroundColor(.secondary).font(.footnote)
          Text("3. Enter the secret code in your authenticator app").foregroundColor(.secondary).font(.footnote)
          Text("4. Enter the verification code to complete setup").foregroundColor(.secondary).font(.footnote)
        }

        Button {
          Task { await generateSecret() }
        } label: {
          if isLoading {
            ProgressView()
              .frame(maxWidth: .infinity)
          } else {
            Text("Generate Secret")
              .frame(maxWidth: .infinity)
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading)
      }
    }
  }

  private var verifyStep: some View {
    CardContainer {
      VStack(alignment: .leading, spacing: 16) {
        Text("Scan QR Code or Copy Secret")
          .font(.headline)
          .fontWeight(.bold)

        if let totpUri = totpUri(), let img = qrImage(from: totpUri) {
          HStack {
            Spacer()
            img
              .interpolation(.none)
              .resizable()
              .frame(width: 200, height: 200)
              .padding(12)
              .background(Color.white)
              .cornerRadius(8)
              .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
            Spacer()
          }
        }

        Divider()

        Text("Or copy the secret code manually:")
          .fontWeight(.medium)

        if let secret = deviceInfo?.secret {
          VStack(spacing: 12) {
            Text(secret)
              .font(.system(.footnote, design: .monospaced))
              .textSelection(.enabled)
              .frame(maxWidth: .infinity)
              .padding(12)
              .background(Color(.systemGray6))
              .cornerRadius(6)

            Button {
              #if canImport(UIKit)
              UIPasteboard.general.string = secret
              #endif
            } label: {
              Label("Copy Secret", systemImage: "doc.on.doc")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
          }
        }

        Divider()

        TextFieldWithLabel(
          label: "Verification Code",
          placeholder: "Enter 6-digit code from your authenticator app",
          text: $code,
          keyboardType: .numberPad
        )

        Button {
          Task { await verifyDevice() }
        } label: {
          if isLoading {
            ProgressView()
              .frame(maxWidth: .infinity)
          } else {
            Text("Verify & Add Device")
              .frame(maxWidth: .infinity)
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
  }

  private func generateSecret() async {
    isLoading = true
    do {
      deviceInfo = try await sdk.mfa.addDevice(type: "totp")
      step = .verify
    } catch {
      alertTitle = "Error"
      alertMessage = "Failed to add MFA device: \(error)"
    }
    isLoading = false
  }

  private func verifyDevice() async {
    guard deviceInfo != nil else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      try await sdk.mfa.verifyDevice(code.trimmingCharacters(in: .whitespacesAndNewlines), type: "totp")
      alertTitle = "Success"
      alertMessage = "MFA device added successfully"
    } catch {
      alertTitle = "Error"
      alertMessage = "Failed to verify MFA device. Please check your code and try again."
    }
  }

  private func totpUri() -> String? {
    guard let deviceInfo else { return nil }
    let secret = deviceInfo.secret
    let user = sdk.auth.authenticatedUser
    let accountName = user?.email ?? user?.userId ?? "Account"
    let issuer = sdk.props.appName ?? "Dynamic"
    return "otpauth://totp/\(issuer.urlEncoded):\(accountName.urlEncoded)?secret=\(secret)&issuer=\(issuer.urlEncoded)"
  }

  private func qrImage(from string: String) -> Image? {
    let data = Data(string.utf8)
    qrFilter.setValue(data, forKey: "inputMessage")
    qrFilter.correctionLevel = "M"
    guard let output = qrFilter.outputImage else { return nil }
    let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
    guard let cg = ciContext.createCGImage(scaled, from: scaled.extent) else { return nil }
    return Image(decorative: cg, scale: 1.0, orientation: .up)
  }
}


