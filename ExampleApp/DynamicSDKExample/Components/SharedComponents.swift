import SwiftUI

/// Reusable text field component with label.
struct TextFieldWithLabel: View {
  let label: String
  let placeholder: String
  @Binding var text: String
  var keyboardType: UIKeyboardType = .default
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(label)
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundColor(.primary)
      
      TextField(placeholder, text: $text)
        .keyboardType(keyboardType)
        .textFieldStyle(.plain)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
  }
}

/// Reusable button component.
struct PrimaryButton: View {
  let title: String
  let action: () -> Void
  var isLoading: Bool = false
  var isDisabled: Bool = false
  
  var body: some View {
    Button(action: action) {
      HStack {
        if isLoading {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
        }
        Text(title)
          .fontWeight(.semibold)
      }
      .frame(maxWidth: .infinity)
      .padding()
      .background(isDisabled ? Color(.systemGray) : Color.blue)
      .foregroundColor(.white)
      .cornerRadius(8)
    }
    .disabled(isDisabled || isLoading)
  }
}

/// Reusable card component for displaying information.
struct InfoCard: View {
  let title: String
  let content: String
  var copyable: Bool = true
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.headline)
        .foregroundColor(.primary)
      
      Text(content)
        .font(.caption)
        .foregroundColor(.secondary)
        .textSelection(.enabled)
      
      if copyable {
        Button(action: {
          UIPasteboard.general.string = content
        }) {
          HStack {
            Image(systemName: "doc.on.doc")
            Text("Copy")
          }
          .font(.caption)
          .foregroundColor(.blue)
        }
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.systemBackground).opacity(0.8))
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color(.systemGray5), lineWidth: 1)
    )
  }
}

/// Error message component.
struct ErrorMessageView: View {
  let message: String
  
  var body: some View {
    HStack {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundColor(.red)
      Text(message)
        .font(.caption)
        .foregroundColor(.red)
      Spacer()
    }
    .padding()
    .background(Color.red.opacity(0.1))
    .cornerRadius(8)
  }
}

/// Success message component.
struct SuccessMessageView: View {
  let message: String
  
  var body: some View {
    HStack {
      Image(systemName: "checkmark.circle.fill")
        .foregroundColor(.green)
      Text(message)
        .font(.caption)
        .foregroundColor(.green)
      Spacer()
    }
    .padding()
    .background(Color.green.opacity(0.1))
    .cornerRadius(8)
  }
}

/// Simple OTP sheet used for Email/SMS OTP flows (mirrors Flutter example UX).
struct OtpVerificationSheet: View {
  let title: String
  let subtitle: String?
  let onVerify: (_ code: String) async throws -> Void
  let onResend: () async throws -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var code: String = ""
  @State private var isLoading: Bool = false
  @State private var errorMessage: String?
  @State private var didVerify: Bool = false

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 16) {
        Text(title)
          .font(.title2)
          .fontWeight(.bold)

        if let subtitle {
          Text(subtitle)
            .font(.subheadline)
            .foregroundColor(.secondary)
        }

        TextFieldWithLabel(
          label: "OTP code",
          placeholder: "123456",
          text: $code,
          keyboardType: .numberPad
        )

        if let errorMessage {
          ErrorMessageView(message: errorMessage)
        }

        if didVerify {
          SuccessMessageView(message: "Verified!")
        }

        PrimaryButton(
          title: isLoading ? "Verifying..." : "Verify",
          action: { Task { await verify() } },
          isLoading: isLoading,
          isDisabled: code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )

        Button(action: { Task { await resend() } }) {
          Text("Resend code")
            .frame(maxWidth: .infinity)
        }
        .disabled(isLoading)

        Spacer()
      }
      .padding()
      .navigationTitle("Verify OTP")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
        }
      }
    }
  }

  private func verify() async {
    let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    isLoading = true
    errorMessage = nil
    didVerify = false
    do {
      try await onVerify(trimmed)
      didVerify = true
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
    isLoading = false
  }

  private func resend() async {
    isLoading = true
    errorMessage = nil
    do {
      try await onResend()
    } catch {
      errorMessage = error.localizedDescription
    }
    isLoading = false
  }
}

#Preview {
  VStack(spacing: 20) {
    TextFieldWithLabel(
      label: "Email",
      placeholder: "your@email.com",
      text: .constant("")
    )
    
    PrimaryButton(title: "Submit", action: {})
    
    InfoCard(
      title: "Transaction Hash",
      content: "0x1234567890abcdef..."
    )
    
    ErrorMessageView(message: "Something went wrong")
    
    SuccessMessageView(message: "Transaction successful!")
  }
  .padding()
}

