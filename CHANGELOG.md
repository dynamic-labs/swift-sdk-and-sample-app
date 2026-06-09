# Changelog

All notable changes to the `DynamicSDKSwift` package are documented here.
This project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.13]

### Fixed
- **MFA `getUserDevices()` decoding.** `getUserDevices()` (and `verifyDevice()`) could throw a `DecodingError` ("data couldn't be read because it isn't in the correct format") because dates returned across the WebView bridge are ISO-8601 with fractional seconds (e.g. `2024-05-01T12:34:56.789Z`), which the previous `.iso8601` decoding strategy rejected. Date decoding now accepts ISO-8601 with and without fractional seconds (plus a numeric-epoch fallback).
- **MFA unknown device type.** An unrecognized `MfaDevice.type` value no longer fails the whole device list — it now decodes as `nil`.
- **iOS 18 reveal/overlay crash.** Worked around a UIKit gesture-graph assertion (`-[UIGestureGraphEdge initWithLabel:sourceNode:targetNode:]`, *"Invalid parameter not satisfying: targetNode"*) that could crash the app on the first touch of the SDK WebView overlay (e.g. `revealEmbeddedWalletPrivateKey()`) on iOS 18. No-ops on iOS 26+, where Apple fixed the underlying bug.

### Added
- minJWT token support.

### Changed
- Bumped bundled WebView to `4.88.3`.

## [1.0.12]
- Add BTC and TON support.

## [1.0.11]
- Add WalletConnect, Step-Up & Trusted Devices UIs.

## [1.0.10]
- Add raw message signing.

## [1.0.9]
- Add SUI wallet screens; update SDK frameworks.

## [1.0.8]
- Fix sponsored transactions.

## [1.0.7]
- Fix SPL token transfer.

## [1.0.6]
- Fix bugs caused by a Swift compiler issue.

## [1.0.5]
- Fixes for Sign In With JWT.

## [1.0.4]
- Update sample app; use `String` instead of `BigUInt` for `EthereumTransaction` signatures.

## [1.0.3]
- Add reveal private key and custom token balance retrieval.

## [1.0.2]
- Update sample app and core SDK.
