import Foundation

@MainActor
final class AuthViewModel: ObservableObject {

    // Exposed to UI
    @Published var email = ""
    @Published var password = ""
    @Published var isRegisterMode = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let flows: AuthFlowService

    init(flows: AuthFlowService) {
        self.flows = flows
    }

    // MARK: - Entry

    func submit() {
        if isRegisterMode {
            Task { await register() }
        } else {
            Task { await login() }
        }
    }

    // MARK: - Email login

    private func login() async {
        guard validateFields() else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await flows.signInEmail(email: email, password: password)
        } catch let err as AuthError {
            errorMessage = mapError(err)
        } catch {
            errorMessage = "Unknown error"
        }

        isLoading = false
    }

    // MARK: - Email register

    private func register() async {
        guard validateFields() else { return }

        isLoading = true
        errorMessage = nil

        do {
            let data = EmailSignUpData(
                email: email,
                password: password,
                language: "en",
                chatColor: "default",
                avatarStyle: "default"
            )

            try await flows.registerEmail(data)
        } catch let err as AuthError {
            errorMessage = mapError(err)
        } catch {
            errorMessage = "Unknown error"
        }

        isLoading = false
    }

    // MARK: - Apple / Google

    func signInWithApple() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                try await flows.signInApple(defaultLanguage: "en")
            } catch {
                errorMessage = "Apple login failed"
            }
            isLoading = false
        }
    }

    func signInWithGoogle() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                try await flows.signInGoogle(defaultLanguage: "en")
            } catch {
                errorMessage = "Google login failed"
            }
            isLoading = false
        }
    }

    // MARK: - Validation / Error mapping

    private func validateFields() -> Bool {
        if email.isEmpty || password.isEmpty {
            errorMessage = "Email and password required"
            return false
        }
        return true
    }

    private func mapError(_ err: AuthError) -> String {
        switch err {
        case .emailAlreadyInUse:  return "This email is already registered."
        case .invalidEmail:       return "Invalid email"
        case .wrongPassword:      return "Wrong password"
        case .weakPassword:       return "Password too weak"
        case .userDisabled:       return "Account disabled"
        case .userNotFound:       return "No user found"
        case .requiresRecentLogin:return "Please re-authenticate"
        case .noUser, .unknown:   return "Unknown error"
        }
    }
}
