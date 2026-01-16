import SwiftUI
import DynamicSDKSwift

struct EvmSignTypedDataScreen: View {
  let wallet: BaseWallet
  
  @State private var typedData: String = """
  {
    "types": {
      "EIP712Domain": [
        {"name": "name", "type": "string"},
        {"name": "version", "type": "string"},
        {"name": "chainId", "type": "uint256"},
        {"name": "verifyingContract", "type": "address"}
      ],
      "Person": [
        {"name": "name", "type": "string"},
        {"name": "wallet", "type": "address"}
      ]
    },
    "primaryType": "Person",
    "domain": {
      "name": "Ether Mail",
      "version": "1",
      "chainId": 1,
      "verifyingContract": "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
    },
    "message": {
      "name": "Bob",
      "wallet": "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"
    }
  }
  """
  @State private var signature: String?
  @State private var errorMessage: String?
  @State private var isLoading: Bool = false
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // Info Card
        InfoCard(
          title: "Sign Typed Data (EIP-712)",
          content: "Sign structured data according to EIP-712 standard."
        )
        
        // Typed Data Input
        VStack(alignment: .leading, spacing: 8) {
          Text("Typed Data (JSON)")
            .font(.headline)
          
          TextEditor(text: $typedData)
            .font(.system(.caption, design: .monospaced))
            .frame(minHeight: 300)
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        
        // Sign Button
        PrimaryButton(
          title: isLoading ? "Signing..." : "Sign Typed Data",
          action: signTypedData,
          isLoading: isLoading
        )
        
        // Error Message
        if let error = errorMessage {
          ErrorMessageView(message: error)
        }
        
        // Success Message
        if let sig = signature {
          SuccessMessageView(
            message: sig
          )
        }
      }
      .padding()
    }
    .navigationTitle("Sign Typed Data")
    .navigationBarTitleDisplayMode(.inline)
  }
  
  private func signTypedData() {
    isLoading = true
    errorMessage = nil
    signature = nil
    
    Task {
      do {
        let sig = try await DynamicSDK.instance().wallets.signTypedData(
          wallet: wallet,
          typedDataJson: typedData
        )
        
        await MainActor.run {
          signature = sig
          isLoading = false
        }
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
          isLoading = false
        }
      }
    }
  }
}

