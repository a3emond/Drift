import SwiftUI

struct AuthView: View {

    @StateObject private var vm: AuthViewModel

    init(flows: AuthFlowService) {
        _vm = StateObject(wrappedValue: AuthViewModel(flows: flows))
    }

    var body: some View {
        VStack(spacing: 24) {

            // Mode toggle
            Picker("", selection: $vm.isRegisterMode) {
                Text("Sign In").tag(false)
                Text("Register").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Email
            TextField("Email", text: $vm.email)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            // Password
            SecureField("Password", text: $vm.password)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            // Error
            if let error = vm.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            // Submit
            Button(action: { vm.submit() }) {
                Text(vm.isRegisterMode ? "Create Account" : "Sign In")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isLoading)

            // Apple / Google
            VStack(spacing: 12) {
                Button {
                    vm.signInWithApple()
                } label: {
                    Text("Continue with Apple")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    vm.signInWithGoogle()
                } label: {
                    Text("Continue with Google")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .disabled(vm.isLoading)

            Spacer()
        }
        .padding()
        .overlay {
            if vm.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
    }
}
