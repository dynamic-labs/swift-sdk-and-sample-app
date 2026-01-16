# Dynamic Swift SDK

iOS SDK for Dynamic's authentication and Web3 wallet infrastructure.

## Features

- **Authentication**: Social (Google, Apple, Farcaster), Email/SMS OTP, Passkey, External JWT
- **Multi-Chain Wallets**: EVM (Ethereum, Polygon, Base, etc.) and Solana
- **Wallet Operations**: Balances, signing, transactions, network switching
- **Security**: MFA/TOTP, Passkey management, Recovery codes
- **Reactive State**: Combine framework integration

## Requirements

- iOS 15.0+ / Xcode 14.0+ / Swift 5.9+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/dynamic-labs/swift-sdk-and-sample-app.git", from: "1.0.0")
]
```

Or via Xcode: **File → Add Package Dependencies** → Enter repository URL

## Quick Start

### Initialize

```swift
import SwiftUI
import DynamicSDKSwift

@main
struct YourApp: App {
    init() {
        _ = DynamicSDK.initialize(
            props: ClientProps(
                environmentId: "YOUR_ENVIRONMENT_ID",
                appLogoUrl: "https://yourdomain.com/logo.png",
                appName: "Your App Name",
                redirectUrl: "yourapp://",
                appOrigin: "https://yourdomain.com"
            )
        )
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

### Access SDK

```swift
let sdk = DynamicSDK.instance()
```

## Authentication

### Built-in UI

```swift
sdk.ui.showAuth()
```

### Social Providers

```swift
try await sdk.auth.social.connect(provider: .google)  // or .apple, .farcaster
```

### Email OTP

```swift
try await sdk.auth.email.sendOTP(email: "user@example.com")
try await sdk.auth.email.verifyOTP(token: "123456")
```

### SMS OTP

```swift
let phoneData = PhoneData(countryCode: "1", phoneNumber: "5555551234")
try await sdk.auth.sms.sendOTP(phoneData: phoneData)
try await sdk.auth.sms.verifyOTP(token: "123456")
```

### Passkey

```swift
try await sdk.auth.passkey.signIn()
try await sdk.passkeys.registerPasskey()
```

### External JWT

```swift
try await sdk.auth.externalAuth.signInWithExternalJwt(
    props: SignInWithExternalJwtParams(jwt: "your-jwt-token")
)
```

### Auth State

```swift
let user = sdk.auth.authenticatedUser

sdk.auth.authenticatedUserChanges
    .receive(on: DispatchQueue.main)
    .sink { user in /* handle user changes */ }
    .store(in: &cancellables)

try await sdk.auth.logout()
```

## Wallet Operations

### Get Wallets & Balance

```swift
let wallets = sdk.wallets.userWallets
let balance = try await sdk.wallets.getBalance(wallet: wallet)
let network = try await sdk.wallets.getNetwork(wallet: wallet)
```

### Network & Primary Wallet

```swift
try await sdk.wallets.switchNetwork(wallet: wallet, network: targetNetwork)
try await sdk.wallets.setPrimary(walletId: walletId)
```

### Sign Message

```swift
let signature = try await sdk.wallets.signMessage(wallet: wallet, message: "Hello!")
```

## EVM Transactions

### Send Transaction

```swift
let client = try await sdk.evm.createPublicClient(chainId: chainId)
let gasPrice = try await client.getGasPrice()

let transaction = EthereumTransaction(
    to: recipientAddress,
    value: amountInWei,
    gasLimit: 21000,
    maxFeePerGas: Int(gasPrice.value * 2),
    maxPriorityFeePerGas: Int(gasPrice.value * 2)
)

let txHash = try await sdk.evm.sendTransaction(transaction: transaction, wallet: wallet)
```

### Sign Typed Data (EIP-712)

```swift
let signature = try await sdk.wallets.signTypedData(wallet: wallet, typedDataJson: typedDataJson)
```

### ERC20 & Contract Interactions

```swift
let input = WriteContractInput(
    contractAddress: tokenContractAddress,
    functionName: "transfer",
    args: [recipientAddress, tokenAmount],
    abi: Erc20.abi
)

let txHash = try await sdk.evm.writeContract(wallet: wallet, input: input)
```

## Solana Transactions

### Sign & Send

```swift
let connection = try await sdk.solana.createConnection()
let signer = try await sdk.solana.createSigner(wallet: wallet)
let blockhash = try await connection.getLatestBlockhash()

let signature = try await signer.signAndSendEncodedTransaction(base64Transaction: base64Tx)
```

## MFA

### Device Management

```swift
let devices = try await sdk.mfa.getUserDevices()

// Add TOTP device
let device = try await sdk.mfa.addDevice(type: .totp)
try await sdk.mfa.verifyDevice(code: "123456", type: .totp)

// Delete device
let token = try await sdk.mfa.createMfaToken(singleUse: true)
try await sdk.mfa.deleteUserDevice(deviceId: deviceId, mfaAuthToken: token)
```

### Recovery Codes

```swift
let codes = try await sdk.mfa.getRecoveryCodes(generateNewCodes: false)
try await sdk.mfa.authenticateRecoveryCode(code: recoveryCode)
```

## Passkey Management

```swift
let passkeys = try await sdk.passkeys.getPasskeys()
try await sdk.passkeys.registerPasskey()
try await sdk.passkeys.deletePasskey(DeletePasskeyRequest(passkeyPublicKeyId: passkeyId))
```

## User Profile

```swift
sdk.ui.showUserProfile()

if let user = sdk.auth.authenticatedUser {
    print("User ID: \(user.userId)")
    print("Email: \(user.email ?? "N/A")")
}
```

## Networks

```swift
let evmNetworks = sdk.networks.evm      // Ethereum, Polygon, Arbitrum, Base, etc.
let solanaNetworks = sdk.networks.solana // Mainnet, Devnet, Testnet
```

## Example App

1. Open `ExampleApp/DynamicSDKExample.xcodeproj`
2. Update `environmentId` in `DynamicSDKExampleApp.swift`
3. Run on iOS Simulator or device

Demonstrates all auth flows, wallet operations, EVM/Solana transactions, MFA, and passkeys.

## Support

- [Documentation](https://docs.dynamic.xyz)
- [Slack Community](https://dynamic.xyz/slack)
