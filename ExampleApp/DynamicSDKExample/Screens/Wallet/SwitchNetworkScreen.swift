import SwiftUI
import DynamicSDKSwift

struct SwitchNetworkScreen: View {
  let wallet: BaseWallet
  @StateObject private var vm: SwitchNetworkViewModel
  @Environment(\.dismiss) private var dismiss

  init(wallet: BaseWallet) {
    self.wallet = wallet
    self._vm = StateObject(wrappedValue: SwitchNetworkViewModel(wallet: wallet))
  }

  var body: some View {
    List {
      if vm.isLoading {
        HStack { Spacer(); ProgressView(); Spacer() }
      } else if let error = vm.errorMessage {
        VStack(alignment: .leading, spacing: 12) {
          Text(error).foregroundColor(.red)
          Button("Retry") { Task { await vm.load() } }
        }
      } else {
        ForEach(vm.networks, id: \.name) { net in
          Button {
            Task { await vm.select(network: net) }
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text(net.name)
                  .fontWeight(.semibold)

                Text(vm.subtitle(for: net))
                  .font(.caption)
                  .foregroundColor(.secondary)
              }

              Spacer()

              if vm.isActive(net) {
                Text("Active")
                  .font(.caption2)
                  .fontWeight(.bold)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(Color.green.opacity(0.2))
                  .foregroundColor(.green)
                  .cornerRadius(6)

                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.green)
              }
            }
          }
          .disabled(vm.isActive(net))
        }
      }
    }
    .navigationTitle("Switch Network")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { Task { await vm.load() } }
    .alert(vm.successTitle, isPresented: $vm.isSuccessAlertPresented) {
      Button("OK") { dismiss() }
    } message: {
      Text(vm.successMessage)
    }
  }
}
