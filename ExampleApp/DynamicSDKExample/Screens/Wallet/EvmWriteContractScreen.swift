import SwiftUI
import DynamicSDKSwift

struct EvmWriteContractScreen: View {
  let wallet: BaseWallet
  
  @State private var contractAddress: String = ""
  @State private var functionName: String = "transfer"
  @State private var abi: String = """
  [
    {
      "inputs": [
        {"name": "recipient", "type": "address"},
        {"name": "amount", "type": "uint256"}
      ],
      "name": "transfer",
      "outputs": [{"name": "", "type": "bool"}],
      "stateMutability": "nonpayable",
      "type": "function"
    }
  ]
  """
  @State private var args: String = """
  ["0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb", "1000000000000000000"]
  """
  @State private var txHash: String?
  @State private var errorMessage: String?
  @State private var isLoading: Bool = false
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // Info Card
        InfoCard(
          title: "Write Contract",
          content: "Call a smart contract function that modifies state."
        )
        
        // Contract Address
        TextFieldWithLabel(
          label: "Contract Address",
          placeholder: "0x...",
          text: $contractAddress
        )
        
        // Function Name
        TextFieldWithLabel(
          label: "Function Name",
          placeholder: "transfer",
          text: $functionName
        )
        
        // ABI
        VStack(alignment: .leading, spacing: 8) {
          Text("Contract ABI (JSON)")
            .font(.headline)
          
          TextEditor(text: $abi)
            .font(.system(.caption, design: .monospaced))
            .frame(minHeight: 200)
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        
        // Arguments
        VStack(alignment: .leading, spacing: 8) {
          Text("Arguments (JSON Array)")
            .font(.headline)
          
          TextEditor(text: $args)
            .font(.system(.caption, design: .monospaced))
            .frame(minHeight: 100)
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        
        // Write Button
        PrimaryButton(
          title: isLoading ? "Sending..." : "Write Contract",
          action: writeContract,
          isLoading: isLoading
        )
        
        // Error Message
        if let error = errorMessage {
          ErrorMessageView(message: error)
        }
        
        // Success Message
        if let hash = txHash {
          SuccessMessageView(
            message: "TX Hash: \(hash)"
          )
        }
      }
      .padding()
    }
    .navigationTitle("Write Contract")
    .navigationBarTitleDisplayMode(.inline)
  }
  
  private func writeContract() {
    guard !contractAddress.isEmpty else {
      errorMessage = "Please enter a contract address"
      return
    }
    
    isLoading = true
    errorMessage = nil
    txHash = nil
    
    Task {
      do {
        // Parse ABI JSON
        guard let abiData = abi.data(using: .utf8),
              let abiArray = try JSONSerialization.jsonObject(with: abiData) as? [[String: Any]] else {
          throw DynamicSDKError.custom("Invalid ABI format")
        }
        
        // Parse args JSON
        guard let argsData = args.data(using: .utf8),
              let argsArray = try JSONSerialization.jsonObject(with: argsData) as? [Any] else {
          throw DynamicSDKError.custom("Invalid arguments format")
        }
        
        let input = WriteContractInput(
          address: contractAddress,
          abi: abiArray,
          functionName: functionName,
          args: argsArray
        )
        
        let hash = try await DynamicSDK.instance().evm.writeContract(
          wallet: wallet,
          input: input
        )
        
        await MainActor.run {
          txHash = hash
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

