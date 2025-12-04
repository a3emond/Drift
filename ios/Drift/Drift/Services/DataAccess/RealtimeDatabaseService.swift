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
