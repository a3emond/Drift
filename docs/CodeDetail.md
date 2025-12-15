## App Folder

### AppEnvironment.swift (last update: Dec 13)

```swift
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

```



### DriftApp.swift

```swift
import SwiftUI

// --- Containers --- //
final class AppEnvironmentContainer: ObservableObject {
    @Published var value: AppEnvironment? = nil
}

final class AppCoordinatorContainer: ObservableObject {
    @Published var value: AppCoordinator? = nil
}

// --- App Entry Point --- //
@main
struct DriftApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var appEnvironment = AppEnvironmentContainer()
    @StateObject private var appCoordinator = AppCoordinatorContainer()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if let env = appEnvironment.value, let coord = appCoordinator.value {
                RootContainerView()
                    .environmentObject(env)
                    .environmentObject(coord)
                    .onChange(of: scenePhase) { _, newPhase in
                        coord.handleScenePhaseChange(newPhase)
                    }
            } else {
                LaunchScreenView()
                    .onAppear { bootstrap() }
            }
        }
    }

    // my cheat to have more control over initialization order
    // basically, at this step the DI is initialized and the coordinator starts listening to auth changes
    private func bootstrap() {
        let env = AppEnvironment()
        appEnvironment.value = env
        appCoordinator.value = AppCoordinator(environment: env)
    }
}

```

### AppCoordinator.swift

```swift
import SwiftUI
import Combine

@Observable
final class AppCoordinator: ObservableObject {

    enum RootRoute {
        case launching
        case unauthenticated
        case mainTabs
    }

    private(set) var rootRoute: RootRoute = .launching

    @ObservationIgnored
    private let environment: AppEnvironment

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    @ObservationIgnored
    private var hasStarted = false

    init(environment: AppEnvironment) {
        self.environment = environment

        NotificationCenter.default.publisher(for: .appDidEnterBackground)
            .sink { [weak self] _ in self?.handleAppDidEnterBackground() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .appWillEnterForeground)
            .sink { [weak self] _ in self?.handleAppWillEnterForeground() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .appWillTerminate)
            .sink { [weak self] _ in self?.handleAppWillTerminate() }
            .store(in: &cancellables)
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        environment.auth.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self else { return }
                self.rootRoute = (user == nil) ? .unauthenticated : .mainTabs
            }
            .store(in: &cancellables)
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:     handleAppBecameActive()
        case .inactive:   handleAppBecameInactive()
        case .background: handleAppMovedToBackground()
        @unknown default: break
        }
    }

    private func handleAppBecameActive() {}
    private func handleAppBecameInactive() {}
    private func handleAppMovedToBackground() {}

    func routeToUnauthenticated() { rootRoute = .unauthenticated }
    func routeToMainTabs()        { rootRoute = .mainTabs }

    private func handleAppDidEnterBackground() {}
    private func handleAppWillEnterForeground() {}
    private func handleAppWillTerminate() {}
}

```

### AppDelegate.swift 

```swift
import FirebaseCore
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()                             // FIRST, before DI init
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        NotificationCenter.default.post(name: .appDidEnterBackground, object: nil)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        NotificationCenter.default.post(name: .appWillEnterForeground, object: nil)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        NotificationCenter.default.post(name: .appWillTerminate, object: nil)
    }
}

extension Notification.Name {
    static let appDidEnterBackground = Notification.Name("Drift.appDidEnterBackground")
    static let appWillEnterForeground = Notification.Name("Drift.appWillEnterForeground")
    static let appWillTerminate      = Notification.Name("Drift.appWillTerminate")
}

```

### LaunchScreenView

```swift
import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ProgressView()
                .tint(.white)
        }
    }
}

```

### RootContainerView.swift

```swift
import SwiftUI

struct RootContainerView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        Group {
            switch coordinator.rootRoute {
            case .launching:
                LaunchScreenView()
            case .unauthenticated:
                AuthView(flows: env.flows)
            case .mainTabs:
                RootTabView()
            }
        }
        .onAppear { coordinator.start() }
    }
    
}

```

### RootTabView.swift

```swift
import SwiftUI

struct RootContainerView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        Group {
            switch coordinator.rootRoute {
            case .launching:
                LaunchScreenView()
            case .unauthenticated:
                AuthView(flows: env.flows)
            case .mainTabs:
                RootTabView()
            }
        }
        .onAppear { coordinator.start() }
    }
    
}

```

---

## Utilities Folder

## Logger.swift

```swift
import Foundation
import os.log

enum LogLevel {
    case debug
    case info
    case warning
    case error
}

enum LogCategory: String {
    case app
    case auth
    case database
    case storage
    case worker
    case ui
    case location
}

protocol Logging {
    func log(_ level: LogLevel,
             _ message: String,
             category: LogCategory,
             error: Error?,
             file: String,
             function: String,
             line: Int)
}

extension Logging {
    func debug(_ message: String,
               category: LogCategory = .app,
               file: String = #fileID,
               function: String = #function,
               line: Int = #line) {
        log(.debug, message, category: category, error: nil, file: file, function: function, line: line)
    }

    func info(_ message: String,
              category: LogCategory = .app,
              file: String = #fileID,
              function: String = #function,
              line: Int = #line) {
        log(.info, message, category: category, error: nil, file: file, function: function, line: line)
    }

    func warning(_ message: String,
                 category: LogCategory = .app,
                 error err: Error? = nil,
                 file: String = #fileID,
                 function: String = #function,
                 line: Int = #line) {
        log(.warning, message, category: category, error: err, file: file, function: function, line: line)
    }

    func error(_ message: String,
               category: LogCategory = .app,
               error err: Error? = nil,
               file: String = #fileID,
               function: String = #function,
               line: Int = #line) {
        log(.error, message, category: category, error: err, file: file, function: function, line: line)
    }
}

final class DriftLogger: Logging {

    static let shared = DriftLogger()

    private let subsystem = "pro.aedev.drift"

    private func osLogger(for category: LogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    func log(_ level: LogLevel,
             _ message: String,
             category: LogCategory,
             error: Error?,
             file: String,
             function: String,
             line: Int) {

        let logger = osLogger(for: category)

        let meta = "[\(file):\(line) \(function)]"
        let full = error != nil
            ? "\(meta) \(message) | error=\(String(describing: error))"
            : "\(meta) \(message)"

        switch level {
        case .debug:
            logger.debug("\(full, privacy: .public)")
        case .info:
            logger.info("\(full, privacy: .public)")
        case .warning:
            logger.warning("\(full, privacy: .public)")
        case .error:
            logger.error("\(full, privacy: .public)")
        }
    }
}

```



---

## Extensions Folder

### firebaseObject.swift

```swift
import Foundation

extension Encodable {
    var firebaseObject: Any {
        guard let data = try? JSONEncoder().encode(self),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            return [:]   // never crash on encode error
        }
        return obj
    }
}

```

### StorageReference+Async.swift

```swift
import Foundation
import FirebaseStorage

extension StorageReference {

    func putDataAsync(_ data: Data, metadata: StorageMetadata?) async throws -> StorageMetadata {
        try await withCheckedThrowingContinuation { continuation in
            self.putData(data, metadata: metadata) { meta, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: meta!)
                }
            }
        }
    }

    func putFileAsync(from url: URL, metadata: StorageMetadata?) async throws -> StorageMetadata {
        try await withCheckedThrowingContinuation { continuation in
            self.putFile(from: url, metadata: metadata) { meta, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: meta!)
                }
            }
        }
    }
}

```

---

## Models Folder

### Path/DatabasePath.swift

```swift
import Foundation

struct DatabasePath {
    let value: String
}

// MARK: - Users

extension DatabasePath {

    enum Users {
        case root(uid: String)
        case settings(uid: String)
        case economy(uid: String)
        case entitlements(uid: String)
        case stats(uid: String)

        var suffix: String {
            switch self {
            case .root(let uid):
                return uid
            case .settings(let uid):
                return "\(uid)/settings"
            case .economy(let uid):
                return "\(uid)/economy"
            case .entitlements(let uid):
                return "\(uid)/entitlements"
            case .stats(let uid):
                return "\(uid)/stats"
            }
        }
    }

    static func users(_ node: Users) -> DatabasePath {
        DatabasePath(value: "users/\(node.suffix)")
    }
}

// MARK: - Bottles

extension DatabasePath {

    enum Bottles {
        case root
        case bottle(id: String)
        case content(id: String)
        case conditions(id: String)
        case status(id: String)

        var suffix: String {
            switch self {
            case .root:
                return ""
            case .bottle(let id):
                return id
            case .content(let id):
                return "\(id)/content"
            case .conditions(let id):
                return "\(id)/conditions"
            case .status(let id):
                return "\(id)/status"
            }
        }
    }

    static func bottles(_ node: Bottles) -> DatabasePath {
        switch node {
        case .root:
            return DatabasePath(value: "bottles")
        default:
            return DatabasePath(value: "bottles/\(node.suffix)")
        }
    }
}

// MARK: - Bottle Openers

extension DatabasePath {

    enum BottleOpeners {
        case opener(bottleId: String, uid: String)
    }

    static func bottleOpeners(_ node: BottleOpeners) -> DatabasePath {
        switch node {
        case .opener(let bottleId, let uid):
            return DatabasePath(value: "bottle_openers/\(bottleId)/\(uid)")
        }
    }
}

// MARK: - Chats

extension DatabasePath {

    enum Chats {
        case room(bottleId: String)
        case message(bottleId: String, messageId: String)
    }

    static func chats(_ node: Chats) -> DatabasePath {
        switch node {
        case .room(let bottleId):
            return DatabasePath(value: "chats/\(bottleId)")
        case .message(let bottleId, let messageId):
            return DatabasePath(value: "chats/\(bottleId)/\(messageId)")
        }
    }
}

// MARK: - Presence

extension DatabasePath {

    enum Presence {
        case user(bottleId: String, uid: String)
    }

    static func presence(_ node: Presence) -> DatabasePath {
        switch node {
        case .user(let bottleId, let uid):
            return DatabasePath(value: "presence/\(bottleId)/\(uid)")
        }
    }
}

// MARK: - Watched

extension DatabasePath {

    enum Watched {
        case root(uid: String)
        case bottle(uid: String, bottleId: String)
    }

    static func watched(_ node: Watched) -> DatabasePath {
        switch node {
        case .root(let uid):
            return DatabasePath(value: "watched/\(uid)")
        case .bottle(let uid, let bottleId):
            return DatabasePath(value: "watched/\(uid)/\(bottleId)")
        }
    }
}

// MARK: - Notifications Queue

extension DatabasePath {

    enum NotificationsQueue {
        case root(uid: String)
        case notification(uid: String, notificationId: String)
    }

    static func notificationsQueue(_ node: NotificationsQueue) -> DatabasePath {
        switch node {
        case .root(let uid):
            return DatabasePath(value: "notifications_queue/\(uid)")
        case .notification(let uid, let notifId):
            return DatabasePath(value: "notifications_queue/\(uid)/\(notifId)")
        }
    }
}

// MARK: - Worker Internal

extension DatabasePath {

    enum WorkerInternal {
        case bottleToCleanup(bottleId: String)
    }

    static func workerInternal(_ node: WorkerInternal) -> DatabasePath {
        switch node {
        case .bottleToCleanup(let bottleId):
            return DatabasePath(value: "worker_internal/bottles_to_cleanup/\(bottleId)")
        }
    }
}
/*
Usage example:
 let path = DatabasePath.bottles(.bottle(id: "abc"))
 // path.value == "bottles/abc"
 
 */

```

### Path/StoragePath.swift

```swift
import Foundation

enum StoragePath {
    
    case userAvatar(userId: String)
    case bottleAsset(bottleId: String, filename: String)
    case chatMedia(bottleId: String, messageId: String, filename: String)
    case temp(filename: String)                 // optional helper
    case raw(path: String)                      // escape hatch only

    var value: String {
        switch self {
        case .userAvatar(let uid):
            return "users/\(uid)/avatar.jpg"

        case .bottleAsset(let bottleId, let filename):
            return "bottles/\(bottleId)/assets/\(filename)"

        case .chatMedia(let bottleId, let messageId, let filename):
            return "chats/\(bottleId)/media/\(messageId)_\(filename)"

        case .temp(let filename):
            return "temp/\(filename)"

        case .raw(let path):
            return path
        }
    }

    // Generates unique filenames safely
    static func generateFilename(ext: String) -> String {
        UUID().uuidString + "." + ext
    }
}

```

### Bottle.swift

```swift
import Foundation

struct Bottle: Codable {
    var owner_uid: String
    var created_at: TimeInterval
    var expires_at: TimeInterval?
    var opened_at: TimeInterval?

    var location: BottleLocation
    var conditions: BottleConditions
    var content: BottleContent

    var chat_enabled: Bool
    var status: BottleStatus
}

struct BottleLocation: Codable {
    var lat: Double
    var lng: Double
}

struct BottleConditions: Codable {
    var password: String?
    var time_window: TimeWindow
    var weather: WeatherCondition
    var exact_location: Bool
    var distance_min: Double?
    var distance_max: Double?
    var unlock_at_time: TimeInterval?
    var one_shot: Bool
}

struct TimeWindow: Codable {
    var start: TimeInterval?
    var end: TimeInterval?
}

struct WeatherCondition: Codable {
    var type: String?
    var threshold: Double?
}

struct BottleContent: Codable {
    var text: String?
    var image_path: String?
    var audio_path: String?
}

struct BottleStatus: Codable {
    var locked: Bool
    var dead: Bool
    var alive_until: TimeInterval
    var active_users_count: Int
}

```

### BottleOpener.swift

```swift
import Foundation

struct BottleOpener: Codable {
    var opened_at: TimeInterval
    var distance_from_drop_km: Double
}

```

### ChatMessage.swift

```swift
import Foundation

struct ChatMessage: Codable {
    var uid: String
    var text: String?
    var image_path: String?
    var audio_path: String?
    var timestamp: TimeInterval
    var distance_category: String
    var translation_memory: [String: String]?
}

```

### NotificationItem.swift

```swift
import Foundation

struct NotificationItem: Codable {
    var type: String
    var bottle_id: String
    var created_at: TimeInterval
    var seen: Bool
}

```

### Presence.swift

```swift
import Foundation

struct NotificationItem: Codable {
    var type: String
    var bottle_id: String
    var created_at: TimeInterval
    var seen: Bool
}

```

### User.swift

```swift
import Foundation

struct DriftUser: Codable {
    var created_at: TimeInterval
    var last_active: TimeInterval

    var settings: UserSettings
    var economy: UserEconomy
    var entitlements: UserEntitlements
    var stats: UserStats
}

extension DriftUser {

    static func initial(language: String,
                        chatColor: String,
                        avatarStyle: String,
                        now: TimeInterval = Date().timeIntervalSince1970) -> DriftUser {

        DriftUser(
            created_at: now,
            last_active: now,
            settings: UserSettings(
                chat_color: chatColor,
                avatar_style: avatarStyle,
                language: language
            ),
            economy: UserEconomy(
                coins: 0,
                bottle_tokens: 0,
                daily_loot_timestamp: 0
            ),
            entitlements: UserEntitlements(
                premium_user: false,
                unlocked_bottle_types: UnlockedBottleTypes(
                    time_locked: false,
                    weather_locked: false,
                    whisper_bottle: false,
                    multi_media_bottle: false,
                    rare_bottle_theme: false
                )
            ),
            stats: UserStats(
                bottles_created: 0,
                bottles_opened: 0,
                distance_traveled_total_km: 0,
                chat_messages_sent: 0
            )
        )
    }
}

struct UserSettings: Codable {
    var chat_color: String
    var avatar_style: String
    var language: String
}

struct UserEconomy: Codable {
    var coins: Int
    var bottle_tokens: Int
    var daily_loot_timestamp: TimeInterval
}

struct UserEntitlements: Codable {
    var premium_user: Bool
    var unlocked_bottle_types: UnlockedBottleTypes
}

struct UnlockedBottleTypes: Codable {
    var time_locked: Bool
    var weather_locked: Bool
    var whisper_bottle: Bool
    var multi_media_bottle: Bool
    var rare_bottle_theme: Bool
}

struct UserStats: Codable {
    var bottles_created: Int
    var bottles_opened: Int
    var distance_traveled_total_km: Double
    var chat_messages_sent: Int
}

```

### WatchedBottle.swift

```swift
import Foundation

struct WatchedBottle: Codable {
    var saved_at: TimeInterval
    var notified_ready: Bool
}

```

### WorkerInternal.swift

```swift
import Foundation

// IMPORTANT: This model is used internally by the background worker and is not exposed to the app directly.
// Here for completeness, it is placed in the Models folder.
struct BottleCleanupEntry: Codable {
    var expires_at: TimeInterval
}

```

---

## Services Folder

### DataAccess/RealtimeDatabaseService.swift

```swift
import Foundation
import FirebaseDatabase

final class RealtimeDatabaseService {

    private let root: DatabaseReference
    private let logger: Logging

    init(database: Database = Database.database(),
         logger: Logging = DriftLogger.shared) {
        self.root = database.reference()
        self.logger = logger

        logger.debug("RealtimeDatabaseService initialized",
                     category: .database)
    }

    private func ref(for path: DatabasePath) -> DatabaseReference {
        root.child(path.value)
    }

    // ----------------------------------------------------------
    // MARK: - Basic CRUD (Codable)
    // ----------------------------------------------------------

    func get<T: Decodable>(_ type: T.Type,
                           at path: DatabasePath) async throws -> T? {

        logger.debug("GET \(path.value)", category: .database)

        do {
            let snapshot = try await ref(for: path).getData()

            guard snapshot.exists(), let value = snapshot.value else {
                logger.info("GET miss: \(path.value)", category: .database)
                return nil
            }

            let decoded: T = try decode(value, as: T.self)

            logger.debug("GET success \(path.value)", category: .database)
            return decoded

        } catch {
            logger.error("GET failed \(path.value)",
                         category: .database,
                         error: error)
            throw error
        }
    }

    func set<T: Encodable>(_ value: T,
                           at path: DatabasePath) async throws {

        logger.debug("SET \(path.value)", category: .database)

        do {
            let object = try encodeToFirebaseObject(value)
            try await ref(for: path).setValue(object)

            logger.info("SET success \(path.value)",
                        category: .database)

        } catch {
            logger.error("SET failed \(path.value)",
                         category: .database,
                         error: error)
            throw error
        }
    }

    func update(_ values: [String: Any],
                at path: DatabasePath) async throws {

        logger.debug("UPDATE \(path.value)", category: .database)

        do {
            try await ref(for: path).updateChildValues(values)

            logger.info("UPDATE success \(path.value)",
                        category: .database)

        } catch {
            logger.error("UPDATE failed \(path.value)",
                         category: .database,
                         error: error)
            throw error
        }
    }

    func delete(at path: DatabasePath) async throws {

        logger.debug("DELETE \(path.value)", category: .database)

        do {
            try await ref(for: path).removeValue()

            logger.info("DELETE success \(path.value)",
                        category: .database)

        } catch {
            logger.error("DELETE failed \(path.value)",
                         category: .database,
                         error: error)
            throw error
        }
    }

    // ----------------------------------------------------------
    // MARK: - Decode / Encode helpers
    // ----------------------------------------------------------

    private func encodeToFirebaseObject<T: Encodable>(_ value: T) throws -> Any {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data, options: [])
    }

    private func decode<T: Decodable>(_ value: Any,
                                      as type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        return try JSONDecoder().decode(T.self, from: data)
    }

    // ----------------------------------------------------------
    // MARK: - Observers (AsyncStream)
    // ----------------------------------------------------------

    private var observers: [String: DatabaseHandle] = [:]

    func observe<T: Decodable>(_ type: T.Type,
                               at path: DatabasePath) -> AsyncStream<T?> {

        logger.debug("OBSERVE start \(path.value)",
                     category: .database)

        let reference = ref(for: path)
        let key = path.value

        return AsyncStream { continuation in
            let handle = reference.observe(.value) { snapshot in

                if snapshot.exists(), let value = snapshot.value {
                    do {
                        let decoded: T = try self.decode(value, as: T.self)
                        continuation.yield(decoded)
                    } catch {
                        self.logger.error("OBSERVE decode error \(path.value)",
                                          category: .database,
                                          error: error)
                        continuation.yield(nil)
                    }
                } else {
                    continuation.yield(nil)
                }
            }

            self.observers[key] = handle

            continuation.onTermination = { @Sendable _ in
                reference.removeObserver(withHandle: handle)
                self.observers.removeValue(forKey: key)

                self.logger.debug("OBSERVE end \(path.value)",
                                  category: .database)
            }
        }
    }

    func removeObservers(at path: DatabasePath) {
        let key = path.value

        guard let handle = observers[key] else {
            logger.debug("removeObservers: no observers for \(path.value)",
                         category: .database)
            return
        }

        let reference = ref(for: path)
        reference.removeObserver(withHandle: handle)
        observers.removeValue(forKey: key)

        logger.debug("removeObservers success \(path.value)",
                     category: .database)
    }
}

```

### DataAccess/StorageService.swift

```swift
import Foundation
import FirebaseStorage

final class StorageService {

    private let storage: Storage
    private let logger: Logging

    init(storage: Storage = Storage.storage(),
         logger: Logging = DriftLogger.shared) {
        self.storage = storage
        self.logger = logger

        logger.debug("StorageService initialized",
                     category: .storage)
    }

    // ----------------------------------------------------------
    // MARK: - Upload Helpers
    // ----------------------------------------------------------

    func uploadData(_ data: Data,
                    to path: StoragePath,
                    contentType: String) async throws -> URL {

        logger.debug("uploadData to \(path.value) contentType=\(contentType)",
                     category: .storage)

        let ref = storage.reference(withPath: path.value)

        let metadata = StorageMetadata()
        metadata.contentType = contentType

        do {
            _ = try await ref.putDataAsync(data, metadata: metadata)
            let url = try await ref.downloadURL()

            logger.info("uploadData success \(path.value)",
                        category: .storage)

            return url
        } catch {
            logger.error("uploadData failed \(path.value)",
                         category: .storage,
                         error: error)
            throw error
        }
    }

    func uploadFile(_ fileURL: URL,
                    to path: StoragePath,
                    contentType: String) async throws -> URL {

        logger.debug("uploadFile from \(fileURL.lastPathComponent) to \(path.value) contentType=\(contentType)",
                     category: .storage)

        let ref = storage.reference(withPath: path.value)

        let metadata = StorageMetadata()
        metadata.contentType = contentType

        do {
            _ = try await ref.putFileAsync(from: fileURL, metadata: metadata)
            let url = try await ref.downloadURL()

            logger.info("uploadFile success \(path.value)",
                        category: .storage)

            return url
        } catch {
            logger.error("uploadFile failed \(path.value)",
                         category: .storage,
                         error: error)
            throw error
        }
    }

    // ----------------------------------------------------------
    // MARK: - Download Helpers
    // ----------------------------------------------------------

    func downloadData(from path: StoragePath,
                      maxSize: Int64 = 25 * 1024 * 1024) async throws -> Data {

        logger.debug("downloadData from \(path.value) maxSize=\(maxSize)",
                     category: .storage)

        let ref = storage.reference(withPath: path.value)

        do {
            let data = try await ref.data(maxSize: maxSize)

            logger.info("downloadData success \(path.value) size=\(data.count)",
                        category: .storage)

            return data
        } catch {
            logger.error("downloadData failed \(path.value)",
                         category: .storage,
                         error: error)
            throw error
        }
    }

    func downloadURL(for path: StoragePath) async throws -> URL {

        logger.debug("downloadURL for \(path.value)",
                     category: .storage)

        let ref = storage.reference(withPath: path.value)

        do {
            let url = try await ref.downloadURL()

            logger.info("downloadURL success \(path.value)",
                        category: .storage)

            return url
        } catch {
            logger.error("downloadURL failed \(path.value)",
                         category: .storage,
                         error: error)
            throw error
        }
    }

    // ----------------------------------------------------------
    // MARK: - Delete
    // ----------------------------------------------------------

    func delete(_ path: StoragePath) async throws {

        logger.debug("delete \(path.value)",
                     category: .storage)

        let ref = storage.reference(withPath: path.value)

        do {
            try await ref.delete()

            logger.info("delete success \(path.value)",
                        category: .storage)

        } catch {
            logger.error("delete failed \(path.value)",
                         category: .storage,
                         error: error)
            throw error
        }
    }
}

```

### UserAndAuth/UserService.swift, FirebaseAuthService.swift, AuthFlowService.swift

```swift
// UserService
import Foundation

final class UserService {

    private let db: RealtimeDatabaseService
    private let logger: Logging

    init(db: RealtimeDatabaseService,
         logger: Logging = DriftLogger.shared) {
        self.db = db
        self.logger = logger
    }

    // MARK: - Observe / Fetch

    func observe(uid: String) -> AsyncStream<DriftUser?> {
        db.observe(DriftUser.self,
                   at: .users(.root(uid: uid)))
    }

    func fetch(uid: String) async throws -> DriftUser? {
        try await db.get(DriftUser.self,
                         at: .users(.root(uid: uid)))
    }

    // MARK: - Create initial profile

    func createInitial(uid: String,
                       language: String,
                       chatColor: String,
                       avatarStyle: String) async throws {
        logger.info("UserService.createInitial uid=\(uid)",
                    category: .database)

        let user = DriftUser.initial(
            language: language,
            chatColor: chatColor,
            avatarStyle: avatarStyle
        )

        try await db.set(user,
                         at: .users(.root(uid: uid)))
    }

    // MARK: - Ensure exists (for Apple / Google)

    func ensureExists(uid: String,
                      defaultLanguage: String) async throws {
        if let _ = try await fetch(uid: uid) {
            return
        }

        try await createInitial(
            uid: uid,
            language: defaultLanguage,
            chatColor: "default",
            avatarStyle: "default"
        )
    }

    // MARK: - Updates

    func updateSettings(uid: String,
                        _ settings: UserSettings) async throws {
        try await db.update(
            ["settings": settings.firebaseObject],
            at: .users(.root(uid: uid))
        )
    }

    func updateLastActive(uid: String) async throws {
        try await db.update(
            ["last_active": Date().timeIntervalSince1970],
            at: .users(.root(uid: uid))
        )
    }
}


// FirebaseAuthService
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


// AuthFlowService
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

```



---

## Features Folder

### Auth/AuthView.swift

```swift
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

```

## Auth/AuthViewModel.swift

```swift
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

```

---

## Dec 13 plan



## **Phase 2 — Main ViewModel (Map as the spine)**





**Goal:** one central ViewModel driving the app.





### **MapViewModel**

###  **responsibilities**





This becomes the **root runtime brain**.



It should:



- Subscribe to bottle feed

- Expose map annotations

- Handle tap → bottle preview

- Coordinate transitions to:

  

  - BottleDetail
  - BottleCreation

  

- Track user location state

- Expose loading / error states





No chat logic here.

No lifecycle logic here.

Only **discovery + navigation intent**.



------





## **Phase 3 — Build UI outward from the Map**





Order matters:



1. **MapView**

   

   - Read-only UI
   - No logic besides forwarding actions

   

2. **BottleDetailView + ViewModel**

   

   - Uses BottleService
   - Unlock flow
   - Show content
   - Entry point to chat

   

3. **ChatView + ViewModel**

   

   - PresenceService
   - ChatService
   - Lifecycle-sensitive UI

   

4. **Messages Inbox**

   

   - Watched bottles
   - Active chats
   - Notifications

   

5. **Profile**

   

   - Settings
   - Stats
   - Sign out / delete

   
