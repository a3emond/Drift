import Foundation
final class AppEnvironment: ObservableObject {

    let logger: Logging
    let auth: FirebaseAuthService
    let database: RealtimeDatabaseService
    let storage: StorageService

    let users: UserService
    let flows: AuthFlowService

    let location: LocationService
    let bottles: BottleService
    let chat: ChatService

    let mediaDraft: MediaDraftService

    init() {
        let logger = DriftLogger.shared
        self.logger = logger

        self.auth = FirebaseAuthService(logger: logger)
        self.database = RealtimeDatabaseService(logger: logger)
        self.storage = StorageService(logger: logger)

        self.users = UserService(db: database, logger: logger)
        self.flows = AuthFlowService(auth: auth, users: users)

        self.location = LocationService(logger: logger)
        self.bottles = BottleService(db: database, auth: auth, logger: logger)
        self.chat = ChatService(db: database, storage: storage, logger: logger)

        self.mediaDraft = MediaDraftService(logger: logger)
    }
}
