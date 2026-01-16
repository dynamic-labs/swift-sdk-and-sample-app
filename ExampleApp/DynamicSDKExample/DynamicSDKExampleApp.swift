import SwiftUI
import DynamicSDKSwift

@main
struct DynamicSDKExampleApp: App {
  init() {
    // Initialize SDK at app launch (before SwiftUI renders views)
    // Note: UIWindow overlay creation may be deferred if scene is not ready yet
    _ = DynamicSDK.initialize(
      props: ClientProps(
        environmentId: "3e219b76-dcf1-40ab-aad6-652c4dfab4cc",
        appLogoUrl: "https://demo.dynamic.xyz/favicon-32x32.png",
        appName: "Dynamic Swift Demo",
        redirectUrl: "flutterdemo://",
        appOrigin: "https://demo.dynamic.xyz",
        logLevel: .debug,
        debug: ClientDebugProps(webview: true)
      )
    )
  }

  var body: some Scene {
    WindowGroup {
      AppRootView()
    }
  }
}
