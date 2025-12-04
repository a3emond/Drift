import Foundation
import FirebaseAuth
import Combine

final class FirebaseAuthService: ObservableObject {

    @Published private(set) var currentUser: User?

    private var listener: AuthStateDidChangeListenerHandle?
    private let logger: Logging

    init(logger: Logging = DriftLogger.shared) {
        self.logger = logger
        self.currentUser = Auth.auth().currentUser

        logger.debug("FirebaseAuthService initialized currentUser=\(currentUser?.uid ?? "nil")",
                     category: .auth)

        observeAuthChanges()
    }

    deinit {
        if let handle = listener {
            Auth.auth().removeStateDidChangeListener(handle)
            logger.debug("Removed Firebase auth state listener",
                         category: .auth)
        }
    }

    private func observeAuthChanges() {
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.currentUser = user
            self.logger.info("Auth state changed user=\(user?.uid ?? "nil")",
                             category: .auth)
        }
        logger.debug("Registered Firebase auth state listener",
                     category: .auth)
    }

    // --------------------------------------------------------------
    // MARK: - Email / Password
    // --------------------------------------------------------------

    func signUp(email: String, password: String) async throws {
        logger.info("signUp(email: \(email)) started",
                    category: .auth)

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.currentUser = result.user

            logger.info("signUp success uid=\(result.user.uid)",
                        category: .auth)

            do {
                try await result.user.sendEmailVerification()
                logger.info("Email verification sent to \(email)",
                            category: .auth)
            } catch {
                logger.warning("Failed to send verification email to \(email)",
                               category: .auth,
                               error: error)
                // non-fatal
            }

        } catch {
            let mapped = AuthError.from(error)
            logger.error("signUp(email: \(email)) failed",
                         category: .auth,
                         error: error)
            throw mapped
        }
    }

    func signIn(email: String, password: String) async throws {
        logger.info("signIn(email: \(email)) started",
                    category: .auth)

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.currentUser = result.user

            logger.info("signIn(email: \(email)) success uid=\(result.user.uid)",
                        category: .auth)
        } catch {
            let mapped = AuthError.from(error)
            logger.error("signIn(email: \(email)) failed",
                         category: .auth,
                         error: error)
            throw mapped
        }
    }

    func sendPasswordReset(to email: String) async throws {
        logger.info("sendPasswordReset(to: \(email)) started",
                    category: .auth)

        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            logger.info("sendPasswordReset(to: \(email)) success",
                        category: .auth)
        } catch {
            let mapped = AuthError.from(error)
            logger.error("sendPasswordReset(to: \(email)) failed",
                         category: .auth,
                         error: error)
            throw mapped
        }
    }

    func signOut() {
        logger.info("signOut() called",
                    category: .auth)

        do {
            try Auth.auth().signOut()
            self.currentUser = nil
            logger.info("signOut() success",
                        category: .auth)
        } catch {
            logger.error("signOut() failed",
                         category: .auth,
                         error: error)
        }
    }

    func deleteAccount() async throws {
        logger.info("deleteAccount() started",
                    category: .auth)

        guard let user = Auth.auth().currentUser else {
            logger.error("deleteAccount() no current user",
                         category: .auth)
            throw AuthError.noUser
        }

        do {
            try await user.delete()
            logger.info("deleteAccount() success uid=\(user.uid)",
                        category: .auth)
        } catch {
            let mapped = AuthError.from(error)
            logger.error("deleteAccount() failed uid=\(user.uid)",
                         category: .auth,
                         error: error)
            throw mapped
        }
    }

    func reloadUser() async throws {
        logger.debug("reloadUser() started",
                     category: .auth)

        guard let user = Auth.auth().currentUser else {
            logger.debug("reloadUser() skipped, no current user",
                         category: .auth)
            return
        }

        do {
            try await user.reload()
            currentUser = Auth.auth().currentUser
            logger.info("reloadUser() success uid=\(user.uid)",
                        category: .auth)
        } catch {
            let mapped = AuthError.from(error)
            logger.error("reloadUser() failed uid=\(user.uid)",
                         category: .auth,
                         error: error)
            throw mapped
        }
    }

    // --------------------------------------------------------------
    // MARK: - Reauth
    // --------------------------------------------------------------

    func reauthenticate(email: String, password: String) async throws {
        logger.info("reauthenticate(email: \(email)) started",
                    category: .auth)

        guard let user = Auth.auth().currentUser else {
            logger.error("reauthenticate() no current user",
                         category: .auth)
            throw AuthError.noUser
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)

        do {
            try await user.reauthenticate(with: credential)
            logger.info("reauthenticate() success uid=\(user.uid)",
                        category: .auth)
        } catch {
            let mapped = AuthError.from(error)
            logger.error("reauthenticate() failed uid=\(user.uid)",
                         category: .auth,
                         error: error)
            throw mapped
        }
    }

    // --------------------------------------------------------------
    // MARK: - Apple & Google (placeholder, return User)
    // --------------------------------------------------------------

    func signInWithApple() async throws -> User {
        logger.info("signInWithApple() not implemented yet",
                    category: .auth)
        throw AuthError.unknown
    }

    func signInWithGoogle() async throws -> User {
        logger.info("signInWithGoogle() not implemented yet",
                    category: .auth)
        throw AuthError.unknown
    }
}

// MARK: - Error mapping
enum AuthError: Error {
    case noUser
    case emailAlreadyInUse
    case invalidEmail
    case wrongPassword
    case weakPassword
    case userDisabled
    case userNotFound
    case requiresRecentLogin
    case unknown
}

extension AuthError {
    static func from(_ error: Error) -> AuthError {
        let nsError = error as NSError
        let code = AuthErrorCode(rawValue: nsError.code)

        switch code {
        case .emailAlreadyInUse:     return .emailAlreadyInUse
        case .invalidEmail:          return .invalidEmail
        case .wrongPassword:         return .wrongPassword
        case .weakPassword:          return .weakPassword
        case .userDisabled:          return .userDisabled
        case .userNotFound:          return .userNotFound
        case .requiresRecentLogin:   return .requiresRecentLogin
        default:                     return .unknown
        }
    }
}
