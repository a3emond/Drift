import Foundation
import FirebaseDatabase
import FirebaseAuth

// ----------------------------------------------------------
// MARK: - Public Models
// ----------------------------------------------------------

struct MapBottle {
    let id: String
    let owner_uid: String
    let location: BottleLocation
    let status: BottleStatus
    let expiresAt: TimeInterval?
    let ownerUid: String
}

// ----------------------------------------------------------
// MARK: - Protocol
// ----------------------------------------------------------

protocol BottleServiceProtocol: AnyObject {

    /// Stream all bottles for map discovery.
    /// Emits full snapshots on change.
    func observeAllBottles() -> AsyncStream<[MapBottle]>

    /// Create a new bottle entry (metadata only).
    func createBottle(
        id: String,
        from draft: BottleDraft,
        imagePath: String?,
        audioPath: String?
    ) async throws -> String

    /// Register that a user opened a bottle.
    func registerOpener(
        bottleId: String,
        uid: String,
        distanceKm: Double
    ) async throws
    
    func observeBottle(bottleId: String) -> AsyncStream<Bottle?>
    func unlockBottle(bottleId: String, openedAt: TimeInterval) async throws
}

// ----------------------------------------------------------
// MARK: - BottleService
// ----------------------------------------------------------

final class BottleService: BottleServiceProtocol {
    
    var currentUser: User? {
        auth.currentUser
    }

    // ------------------------------------------------------
    // Dependencies
    // ------------------------------------------------------

    private let db: RealtimeDatabaseService
    private let auth: FirebaseAuthService
    private let logger: Logging

    // ------------------------------------------------------
    // Init
    // ------------------------------------------------------

    init(
        db: RealtimeDatabaseService,
        auth: FirebaseAuthService,
        logger: Logging = DriftLogger.shared
    ) {
        self.db = db
        self.auth = auth
        self.logger = logger

        logger.info(
            "BottleService.init authUser=\(auth.currentUser?.uid ?? "nil")",
            category: .database
        )
    }

    // ------------------------------------------------------
    // MARK: - Discovery
    // ------------------------------------------------------

    func observeAllBottles() -> AsyncStream<[MapBottle]> {
        logger.info("BottleService.observeAllBottles() START", category: .database)

        return AsyncStream { continuation in

            logger.info("BottleService.observeAllBottles() attaching observer", category: .database)

            let stream = db.observe(
                [String: Bottle].self,
                at: .bottles(.root)
            )

            Task {
                for await snapshot in stream {

                    guard let snapshot else {
                        logger.warning(
                            "BottleService.observeAllBottles() snapshot=nil",
                            category: .database
                        )
                        continuation.yield([])
                        continue
                    }

                    logger.info(
                        "BottleService.observeAllBottles() rawKeys=\(snapshot.keys)",
                        category: .database
                    )

                    var decoded: [MapBottle] = []

                    for (key, bottle) in snapshot {

                        logger.info(
                            "BottleService.observeAllBottles() decoding bottleId=\(key)",
                            category: .database
                        )

                        logger.debug(
                            """
                            bottle[\(key)] owner=\(bottle.owner_uid)
                            created=\(bottle.created_at)
                            hasStatus=\(true)
                            hasLocation=(\(bottle.location.lat), \(bottle.location.lng))
                            """,
                            category: .database
                        )

                        decoded.append(
                            MapBottle(
                                id: key,
                                owner_uid: bottle.owner_uid,
                                location: bottle.location,
                                status: bottle.status,
                                expiresAt: bottle.expires_at,
                                ownerUid: bottle.owner_uid
                            )
                        )
                    }

                    logger.info(
                        "BottleService.observeAllBottles() decodedCount=\(decoded.count)",
                        category: .database
                    )

                    continuation.yield(decoded)
                }
            }

            continuation.onTermination = { @Sendable reason in
                self.logger.info(
                    "BottleService.observeAllBottles terminated reason=\(String(describing: reason))",
                    category: .database
                )
            }
        }
    }

    // ------------------------------------------------------
    // MARK: - Creation
    // ------------------------------------------------------

    func createBottle(
        id bottleId: String,
        from draft: BottleDraft,
        imagePath: String?,
        audioPath: String?
    ) async throws -> String {

        guard let uid = auth.currentUser?.uid else {
            logger.error("BottleService.createBottle FAILED no authenticated user", category: .database)
            throw AuthError.noUser
        }

        logger.info(
            "BottleService.createBottle START id=\(bottleId) owner=\(uid)",
            category: .database
        )

        let timeWindowPayload: TimeWindow? =
            (draft.timeWindow.start != nil || draft.timeWindow.end != nil) ? draft.timeWindow : nil

        let weatherPayload: WeatherCondition? =
            (draft.weather.type != nil || draft.weather.threshold != nil) ? draft.weather : nil

        let bottle = Bottle(
            owner_uid: uid,
            created_at: draft.createdAt,
            expires_at: nil,
            opened_at: nil,
            location: draft.location,
            conditions: BottleConditions(
                password: draft.password,
                time_window: timeWindowPayload,
                weather: weatherPayload,
                exact_location: draft.exactLocation,
                distance_min: draft.distanceMin,
                distance_max: draft.distanceMax,
                unlock_at_time: draft.unlockAtTime,
                one_shot: draft.oneShot
            ),
            content: BottleContent(
                text: draft.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                image_path: imagePath,
                audio_path: audioPath
            ),
            chat_enabled: draft.chatEnabled,
            status: BottleStatus(
                locked: true,
                dead: false,
                alive_until: Date.distantFuture.timeIntervalSince1970,
                active_users_count: 0
            )
        )

        try await db.set(
            bottle,
            at: .bottles(.bottle(id: bottleId))
        )

        logger.info("BottleService.createBottle SUCCESS id=\(bottleId)", category: .database)
        return bottleId
    }

    // ------------------------------------------------------
    // MARK: - Openers
    // ------------------------------------------------------

    func registerOpener(
        bottleId: String,
        uid: String,
        distanceKm: Double
    ) async throws {

        logger.info(
            "BottleService.registerOpener START bottle=\(bottleId) uid=\(uid) distance=\(distanceKm)",
            category: .database
        )

        let opener = BottleOpener(
            opened_at: Date().timeIntervalSince1970,
            distance_from_drop_km: distanceKm
        )

        try await db.set(
            opener,
            at: .bottleOpeners(
                .opener(bottleId: bottleId, uid: uid)
            )
        )

        logger.info(
            "BottleService.registerOpener SUCCESS bottle=\(bottleId) uid=\(uid)",
            category: .database
        )
    }
    
    func observeBottle(bottleId: String) -> AsyncStream<Bottle?> {
        db.observe(
            Bottle.self,
            at: .bottles(.bottle(id: bottleId))
        )
    }

    func unlockBottle(bottleId: String, openedAt: TimeInterval) async throws {
        // Minimal unlock: flip locked to false + set opened_at
        // We update at the bottle root using child keys.
        try await db.update(
            [
                "status/locked": false,
                "opened_at": openedAt
            ],
            at: .bottles(.bottle(id: bottleId))
        )
    }
}
