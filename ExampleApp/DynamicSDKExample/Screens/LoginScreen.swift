import SwiftUI
import DynamicSDKSwift

struct LoginScreenView: View {
  let onNavigateToHome: () -> Void
  
  @StateObject private var vm = LoginScreenViewModel()
  @Environment(\.colorScheme) var colorScheme
  
  var body: some View {
    ZStack {
      // System background color (white in light mode, black in dark mode)
      (colorScheme == .dark ? Color.black : Color.white)
        .ignoresSafeArea()
      
      ScrollView {
        VStack(spacing: 24) {
          Spacer(minLength: 60)
          
          Text("Dynamic SDK Sample App")
            .font(.largeTitle)
            .fontWeight(.bold)
          
          Text("Please Sign in to continue")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.bottom, 40)
          
          VStack(alignment: .leading, spacing: 8) {
            Text("Email")
              .font(.caption)
              .foregroundColor(.secondary)
            TextField("Enter email", text: $vm.email)
              .padding()
              .background(Color(.systemGray6))
              .cornerRadius(12)
              .autocapitalization(.none)
              .keyboardType(.emailAddress)
          }
          .padding(.horizontal, 20)

          PrimaryButton(
            title: "Send Email OTP",
            action: { vm.sendEmailOTP() },
            isLoading: vm.isSendingEmailOTP,
            isDisabled: vm.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          )
          .padding(.horizontal, 20)
          
          VStack(alignment: .leading, spacing: 8) {
            Text("Phone (US/CA)")
              .font(.caption)
              .foregroundColor(.secondary)
            TextField("Enter phone", text: $vm.phone)
              .padding()
              .background(Color(.systemGray6))
              .cornerRadius(12)
              .keyboardType(.phonePad)
          }
          .padding(.horizontal, 20)

          PrimaryButton(
            title: "Send SMS OTP",
            action: { vm.sendSmsOTP() },
            isLoading: vm.isSendingSmsOTP,
            isDisabled: vm.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          )
          .padding(.horizontal, 20)
          
          VStack(spacing: 16) {
            Button(action: {
              vm.signInWithFarcaster()
            }) {
              HStack {
                Text("🟣")
                  .font(.title3)
                Text("Continue with Farcaster")
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color(.systemGray6))
              .cornerRadius(10)
            }
            
            // Google
            Button(action: {
              vm.signInWithGoogle()
            }) {
              HStack {
                Text("G")
                  .font(.headline)
                  .foregroundColor(.blue)
                Text("Continue with Google")
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color(.systemGray6))
              .cornerRadius(10)
            }
            
            // Apple
            Button(action: {
              vm.signInWithApple()
            }) {
              HStack {
                Image(systemName: "applelogo")
                  .font(.title3)
                Text("Continue with Apple")
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color(.systemGray6))
              .cornerRadius(10)
            }
            
            // Passkey
            Button(action: {
              vm.signInWithPasskey()
            }) {
              HStack {
                Image(systemName: "touchid")
                  .font(.title3)
                Text("Sign in with passkey")
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color(.systemGray6))
              .cornerRadius(10)
            }
          }
          .padding(.horizontal, 20)

          // External JWT (mirrors Flutter demo's "External Auth" dev hook)
          VStack(alignment: .leading, spacing: 8) {
            Text("External JWT (dev)")
              .font(.caption)
              .foregroundColor(.secondary)
            TextField("Paste JWT", text: $vm.externalJwt)
              .padding()
              .background(Color(.systemGray6))
              .cornerRadius(12)
              .autocapitalization(.none)
              .textInputAutocapitalization(.never)
          }
          .padding(.horizontal, 20)

          PrimaryButton(
            title: "Sign in with External JWT",
            action: { vm.signInWithExternalJwt() },
            isLoading: vm.isSigningInWithExternalJwt,
            isDisabled: vm.externalJwt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          )
          .padding(.horizontal, 20)

          if let err = vm.errorMessage {
            ErrorMessageView(message: err)
              .padding(.horizontal, 20)
          }
          
          Divider()
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
          
          Text("Dynamic Widget")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.horizontal, 20)
          
          // Open Auth Flow button
          Button(action: {
            vm.openAuthFlow()
          }) {
            Text("Open Auth Flow")
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color(.systemGray6))
              .cornerRadius(10)
          }
          .padding(.horizontal, 20)
          
          Spacer(minLength: 40)
        }
        .padding(.bottom, 20)
      }
    }
    .navigationTitle("Login")
    .onAppear {
      vm.startListening(onNavigateToHome: onNavigateToHome)
    }
    .sheet(isPresented: $vm.isEmailOtpSheetPresented) {
      OtpVerificationSheet(
        title: "Email verification",
        subtitle: vm.email.isEmpty ? nil : "We sent a code to \(vm.email)",
        onVerify: { code in try await vm.verifyEmailOTP(code: code) },
        onResend: { try await vm.resendEmailOTP() }
      )
    }
    .sheet(isPresented: $vm.isSmsOtpSheetPresented) {
      OtpVerificationSheet(
        title: "SMS verification",
        subtitle: vm.phone.isEmpty ? nil : "We sent a code to \(vm.phone)",
        onVerify: { code in try await vm.verifySmsOTP(code: code) },
        onResend: { try await vm.resendSmsOTP() }
      )
    }
  }
}
