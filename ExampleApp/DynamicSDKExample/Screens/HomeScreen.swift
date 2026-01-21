import SwiftUI
import DynamicSDKSwift

struct HomeScreenView: View {
  let onNavigateToLogin: () -> Void
  
  @StateObject private var vm = HomeScreenViewModel()
  @Environment(\.colorScheme) var colorScheme
  
  var body: some View {
    ZStack {
      (colorScheme == .dark ? Color.black : Color.white)
        .ignoresSafeArea()
      
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("Profile")
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .padding(.horizontal, 16)
            .padding(.top, 20)

            // Menu order:
            // 1) Wallets
            Text("Wallets")
              .font(.title2)
              .fontWeight(.bold)
              .foregroundColor(colorScheme == .dark ? .white : .black)
              .padding(.horizontal)

            if vm.isCreatingWallets {
              HStack {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle())
                Text("Creating wallets...")
                  .foregroundColor(.secondary)
              }
              .padding(.horizontal)
            } else if vm.wallets.isEmpty {
              Text("No wallets connected.")
                .foregroundColor(.secondary)
                .padding(.horizontal)
            } else {
              ForEach(vm.wallets, id: \.address) { wallet in
                NavigationLink(destination: WalletDetailsScreen(wallet: wallet)) {
                  WalletCard(wallet: wallet)
                }
                .buttonStyle(PlainButtonStyle())
              }
            }
          
            // 2) Open Profile button
            Button(action: { vm.showUserProfile() }) {
              HStack {
                Image(systemName: "person.circle")
                Text("Open Profile")
                Spacer()
              }
              .foregroundColor(colorScheme == .dark ? .white : .blue)
              .padding()
              .frame(maxWidth: .infinity)
              .background(Color.blue.opacity(0.1))
              .cornerRadius(8)
            }
            .padding(.horizontal)

            if let err = vm.errorMessage {
              ErrorMessageView(message: err)
                .padding(.horizontal)
            }

            // 3) MFA Devices (separate screen)
            NavigationLink(destination: MfaDevicesScreen()) {
              HStack {
                Image(systemName: "shield.lefthalf.filled")
                Text("MFA Devices")
                Spacer()
                Image(systemName: "chevron.right")
              }
              .foregroundColor(colorScheme == .dark ? .white : .blue)
              .padding()
              .frame(maxWidth: .infinity)
              .background(Color.blue.opacity(0.1))
              .cornerRadius(8)
            }
            .padding(.horizontal)

            // 4) Passkeys (separate screen)
            NavigationLink(destination: PasskeysScreen()) {
              HStack {
                Image(systemName: "key.fill")
                Text("Passkeys")
                Spacer()
                Image(systemName: "chevron.right")
              }
              .foregroundColor(colorScheme == .dark ? .white : .blue)
              .padding()
              .frame(maxWidth: .infinity)
              .background(Color.blue.opacity(0.1))
              .cornerRadius(8)
            }
            .padding(.horizontal)

            // 5) User JSON
            if let user = vm.user {
              let json = user.toJsonString()
              ValueCard(
                title: "User:",
                value: json,
                copyValue: json
              )
            }

            // 6) Token
            if let token = vm.token {
              ValueCard(
                title: "Token:",
                value: token,
                displayValue: truncateMiddle(token),
                copyValue: token
              )
            }

            // 7) Logout (must be last)
            Button(action: { vm.logout() }) {
              HStack {
                Image(systemName: "arrow.left.circle.fill")
                Text("Logout")
                Spacer()
              }
              .padding()
              .frame(maxWidth: .infinity)
              .background(Color.red)
              .foregroundColor(.white)
              .cornerRadius(8)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
      }
    }
    .navigationTitle("Home")
    .onAppear {
      vm.startListening(onNavigateToLogin: onNavigateToLogin)
    }
  }

  private func truncateMiddle(_ value: String, head: Int = 16, tail: Int = 10) -> String {
    guard value.count > (head + tail + 3) else { return value }
    let start = value.prefix(head)
    let end = value.suffix(tail)
    return "\(start)…\(end)"
  }
}
