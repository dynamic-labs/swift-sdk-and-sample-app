import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Shared UI components for Security screens (MFA + Passkeys).

struct CodesSheetModel: Identifiable {
  let id: UUID
  let title: String
  let codes: [String]
}

struct CodesSheet: View {
  let title: String
  let codes: [String]

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 16) {
        ScrollView {
          Text(codes.joined(separator: "\n"))
            .font(.system(.footnote, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        Button("Copy") {
          #if canImport(UIKit)
          UIPasteboard.general.string = codes.joined(separator: "\n")
          #endif
          dismiss()
        }
        .buttonStyle(.borderedProminent)
      }
      .padding(16)
      .navigationTitle(title)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
        }
      }
    }
  }
}

struct CodeInputSheet: View {
  let title: String
  let message: String
  let onCancel: () -> Void
  let onSubmit: (String) -> Void

  @State private var code: String = ""

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 16) {
        Text(message)
          .foregroundColor(.secondary)

        TextFieldWithLabel(
          label: "TOTP Code",
          placeholder: "Enter 6-digit code",
          text: $code,
          keyboardType: .numberPad
        )

        HStack(spacing: 12) {
          Button("Cancel", action: onCancel)
            .buttonStyle(.bordered)
          Button("OK") { onSubmit(code) }
            .buttonStyle(.borderedProminent)
        }
      }
      .padding(16)
      .navigationTitle(title)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close", action: onCancel)
        }
      }
    }
  }
}

struct CardContainer<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    content
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(.systemBackground))
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color(.systemGray5), lineWidth: 1)
      )
  }
}

extension String {
  var urlEncoded: String {
    addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
  }
}

extension Date {
  var yyyyMmDd: String {
    let c = Calendar(identifier: .gregorian)
    let y = c.component(.year, from: self)
    let m = c.component(.month, from: self)
    let d = c.component(.day, from: self)
    return "\(y)-\(String(format: "%02d", m))-\(String(format: "%02d", d))"
  }
}


