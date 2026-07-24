import SwiftUI
import DynamicSDKSwift

@main
struct DynamicSDKExampleApp: App {
  init() {
      
      let b3SepoliaNetwork = GenericNetwork(
          blockExplorerUrls: [
              "https://sepolia-explorer.b3.fun"
          ],
          chainId: 1993,
          chainName: "B3 Sepolia",
          iconUrls: [
              "https://icodrops.com/media/projects/covers/b3-fun_cover_1740116094.webp"
          ],
          lcdUrl: nil,
          name: "B3 Sepolia",
          nameService: nil,
          nativeCurrency: NativeCurrency(
              decimals: 18,
              name: "Ether",
              symbol: "ETH",
          ),
          networkId: 1993,
          privateCustomerRpcUrls: nil,
          rpcUrls: [
              "https://sepolia.b3.fun"
          ],
          vanityName: nil
      )
      
      
    _ = DynamicSDK.initialize(
      props: ClientProps(
        environmentId: "f25b5211-a37a-445f-ba53-c3a75783a869",
        appLogoUrl: "https://demo.dynamic.xyz/favicon-32x32.png",
        appName: "Dynamic Swift Demo",
        redirectUrl: "flutterdemo://",
        appOrigin: "https://demo.dynamic.xyz",
        logLevel: .debug,
        debug: ClientDebugProps(webview: true, messageTransport: true)
      )
    )
  }

  var body: some Scene {
    WindowGroup {
      WcGlobalListener {
        AppRootView()
      }
    }
  }
}
