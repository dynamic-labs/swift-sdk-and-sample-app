import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ValueCard: View {
  let title: String
  let value: String
  let displayValue: String
  let copyValue: String?
  @State private var showCopiedAlert = false
  @Environment(\.colorScheme) var colorScheme

  init(
    title: String,
    value: String,
    displayValue: String? = nil,
    copyValue: String? = nil
  ) {
    self.title = title
    self.value = value
    self.displayValue = displayValue ?? value
    self.copyValue = copyValue
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.headline)
        .foregroundColor(colorScheme == .dark ? .white : .black)

      ScrollView {
        Text(displayValue)
          .font(.system(.footnote, design: .monospaced))
          .foregroundColor(colorScheme == .dark ? .white : .black)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxHeight: 300)
      .padding(8)
      .background(Color(.systemGray6))
      .cornerRadius(8)

      Button(action: {
        #if canImport(UIKit)
        UIPasteboard.general.string = copyValue ?? value
        #endif
        showCopiedAlert = true
      }) {
        Text("Copy")
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color.blue)
          .foregroundColor(.white)
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
    .padding(.horizontal)
    .alert("Copied to clipboard", isPresented: $showCopiedAlert) {
      Button("OK", role: .cancel) {}
    }
  }
}


