import Foundation

struct EmailSignUpData {
    let email: String
    let password: String
    let language: String
    let chatColor: String
    let avatarStyle: String
}

final class AuthFlowService {

    private let auth: FirebaseAuthService
    private let users: UserService

    init(auth: FirebaseAuthService,
         users: UserService) {
        self.auth = auth
        self.users = users
    }

    // ----------------------------------------------------------
    // MARK: - Email Sign Up (Auth + DriftUser)
    // ----------------------------------------------------------

    func registerEmail(_ data: EmailSignUpData) async throws {
        try await auth.signUp(email: data.email, password: data.password)

        guard let user = auth.currentUser else {
            throw AuthError.noUser
        }

        try await users.createInitial(
            uid: user.uid,
            language: data.language,
            chatColor: data.chatColor,
            avatarStyle: data.avatarStyle
        )
    }

    // ----------------------------------------------------------
    // MARK: - Email Login (no DB action)
    // ----------------------------------------------------------

    func signInEmail(email: String, password: String) async throws {
        try await auth.signIn(email: email, password: password)
    }

    // ----------------------------------------------------------
    // MARK: - Apple
    // ----------------------------------------------------------

    func signInApple(defaultLanguage: String) async throws {
        let firebaseUser = try await auth.signInWithApple()
        try await users.ensureExists(uid: firebaseUser.uid,
                                     defaultLanguage: defaultLanguage)
    }

    // ----------------------------------------------------------
    // MARK: - Google
    // ----------------------------------------------------------

    func signInGoogle(defaultLanguage: String) async throws {
        let firebaseUser = try await auth.signInWithGoogle()
        try await users.ensureExists(uid: firebaseUser.uid,
                                     defaultLanguage: defaultLanguage)
    }

    // ----------------------------------------------------------
    // MARK: - Pass-through
    // ----------------------------------------------------------

    func signOut()          { auth.signOut() }
    func deleteAccount()    async throws { try await auth.deleteAccount() }
    func resetPassword(_ email: String) async throws { try await auth.sendPasswordReset(to: email) }
    func reauthenticate(email: String, password: String) async throws {
        try await auth.reauthenticate(email: email, password: password)
    }
}
