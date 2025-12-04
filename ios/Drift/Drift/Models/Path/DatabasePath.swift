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
