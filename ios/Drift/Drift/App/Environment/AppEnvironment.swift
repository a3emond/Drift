import Foundation
import SwiftUI

final class AppEnvironment: ObservableObject {

    let logger: Logging

    let auth: FirebaseAuthService
    let database: RealtimeDatabaseService
    let storage: StorageService

    let users: UserService
    let flows: AuthFlowService

    init() {
        let logger = DriftLogger.shared
        self.logger = logger

        self.auth = FirebaseAuthService(logger: logger)
        self.database = RealtimeDatabaseService(logger: logger)
        self.storage = StorageService(logger: logger)

        self.users = UserService(db: database)
        self.flows = AuthFlowService(auth: auth, users: users)
    }
}
