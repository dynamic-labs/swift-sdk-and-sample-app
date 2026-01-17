import Foundation
import Combine
import DynamicSDKSwift

@MainActor
final class LoginScreenViewModel: ObservableObject {
  @Published var email: String = ""
  @Published var phone: String = ""
  @Published var externalJwt: String = ""

  @Published var isSendingEmailOTP: Bool = false
  @Published var isSendingSmsOTP: Bool = false
  @Published var isSigningInWithExternalJwt: Bool = false

  @Published var isEmailOtpSheetPresented: Bool = false
  @Published var isSmsOtpSheetPresented: Bool = false

  @Published var errorMessage: String?

  private let sdk = DynamicSDK.instance()
  private var cancellables = Set<AnyCancellable>()
  private var onNavigateToHome: (() -> Void)?

  func startListening(onNavigateToHome: @escaping () -> Void) {
    self.onNavigateToHome = onNavigateToHome

    if sdk.auth.authenticatedUser != nil {
      onNavigateToHome()
      return
    }

    sdk.auth.authenticatedUserChanges
      .receive(on: DispatchQueue.main)
      .sink { [weak self] user in
        guard let self else { return }
        if user != nil {
          self.onNavigateToHome?()
        }
      }
      .store(in: &cancellables)
  }

  func openAuthFlow() {
    sdk.ui.showAuth()
  }

  func sendEmailOTP() {
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    errorMessage = nil
    isSendingEmailOTP = true
    Task { @MainActor in
      do {
        try await sdk.auth.email.sendOTP(email: trimmed)
        isEmailOtpSheetPresented = true
      } catch {
        errorMessage = "Failed to send email OTP: \(error)"
      }
      isSendingEmailOTP = false
    }
  }

  func verifyEmailOTP(code: String) async throws {
    let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    try await sdk.auth.email.verifyOTP(token: trimmed)
  }

  func resendEmailOTP() async throws {
    try await sdk.auth.email.resendOTP()
  }

  func sendSmsOTP() {
    let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    errorMessage = nil
    isSendingSmsOTP = true
    Task { @MainActor in
      do {
        let phoneData: PhoneData
        
        if trimmed.hasPrefix("+1") {
          // Case 1: Has "+1" prefix -> remove it and send the rest
          let phoneNumber = String(trimmed.dropFirst(2))
          phoneData = PhoneData(dialCode: "+1", iso2: "US", phone: phoneNumber)
        } else if trimmed.hasPrefix("+") {
          // Case 2: Has "+" but not "+1" -> error (only US/CA supported)
          errorMessage = "Only United States/Canada phone numbers are supported"
          isSendingSmsOTP = false
          return
        } else {
          // Case 3: No "+" prefix -> send as-is (assume US/CA)
          phoneData = PhoneData(dialCode: "+1", iso2: "US", phone: trimmed)
        }
        
        try await sdk.auth.sms.sendOTP(phoneData: phoneData)
        isSmsOtpSheetPresented = true
      } catch {
        errorMessage = "Failed to send SMS OTP: \(error)"
      }
      isSendingSmsOTP = false
    }
  }

  func verifySmsOTP(code: String) async throws {
    let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    try await sdk.auth.sms.verifyOTP(token: trimmed)
  }

  func resendSmsOTP() async throws {
    try await sdk.auth.sms.resendOTP()
  }

  func signInWithFarcaster() {
    errorMessage = nil
    Task { @MainActor in
      do {
        try await sdk.auth.social.connect(provider: .farcaster)
      } catch {
        errorMessage = "Farcaster sign-in failed: \(error)"
      }
    }
  }

  func signInWithGoogle() {
    errorMessage = nil
    Task { @MainActor in
      do {
        try await sdk.auth.social.connect(provider: .google)
      } catch {
        errorMessage = "Google sign-in failed: \(error)"
      }
    }
  }

  func signInWithApple() {
    errorMessage = nil
    Task { @MainActor in
      do {
        try await sdk.auth.social.connect(provider: .apple)
      } catch {
        errorMessage = "Apple sign-in failed: \(error)"
      }
    }
  }

  func signInWithPasskey() {
    errorMessage = nil
    Task { @MainActor in
      do {
        _ = try await sdk.auth.passkey.signIn()
      } catch {
        errorMessage = "Passkey sign-in failed: \(error)"
      }
    }
  }

  func signInWithExternalJwt() {
    let trimmed = externalJwt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    errorMessage = nil
    isSigningInWithExternalJwt = true
    Task { @MainActor in
      defer { isSigningInWithExternalJwt = false }
      do {
        try await sdk.auth.externalAuth.signInWithExternalJwt(props: SignInWithExternalJwtParams(jwt: trimmed))
      } catch {
        errorMessage = "External JWT sign-in failed: \(error)"
      }
    }
  }
}


