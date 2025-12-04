# Drift – Technical Architecture

Target stack:

- Client: iOS (Swift / SwiftUI)
- Backend services: Firebase (Auth, Realtime Database, Storage, Cloud Messaging)
- Worker service: Custom .NET (C#) backend, self-hosted on Linux

This document defines the high-level architecture and component responsibilities for Drift. It focuses only on technical structure and runtime behavior.

------

## 1. High-Level System Overview

Drift is built around three main execution environments:

1. iOS client app
2. Firebase platform services
3. Drift Worker Service (C#/.NET on Linux)

### 1.1 Component Overview

```mermaid
flowchart LR
    A[iOS App] --> B((Firebase))

    subgraph Firebase Services
        C[Auth]
        D[Realtime Database]
        E[Storage]
        F[Cloud Messaging FCM]
        G[Optional Cloud Functions]
    end

    B --> C
    B --> D
    B --> E
    B --> F
    B --> G

    subgraph Worker["Drift Worker Service .NET"]
        H[Lifecycle Processor]
        I[Presence Monitor]
        J[Cleanup Processor]
        K[Notification Dispatcher]
    end

    H --> D
    I --> D
    J --> D
    K --> F

```

Responsibilities at a glance:

- iOS App: UI, interactions, and direct Firebase access.
- Firebase: Authentication, data storage, media storage, push infrastructure.
- Worker Service: Enforces lifecycle rules, presence-based survival, cleanup, and complex notification logic.

------

## 2. Core Data Model (Conceptual)

This section describes the main entities as stored in Firebase Realtime Database and Storage.

### 2.1 Main Entities

- `User` (anonymous account authenticated via Firebase Auth)
- `Bottle`
- `BottleChat` (messages under a bottle)
- `BottlePresence` (who is currently inside the chat)
- `BottleWatch` (user-saved bottles)
- `BottleLifecycleState` (runtime state maintained/verified by worker)

### 2.2 Conceptual Data Model Diagram

```mermaid
erDiagram
    USER ||--o{ BOTTLE : creates
    USER ||--o{ BOTTLEWATCH : watches
    BOTTLE ||--o{ BOTTLECHAT : has
    BOTTLE ||--o{ BOTTLEPRESENCE : tracked

    USER {
        string userId
        string anonAvatarId
        string chatColorId
        string preferredLanguage
    }

    BOTTLE {
        string bottleId
        string ownerUserId
        float latitude
        float longitude
        string regionKey
        string status
        string visibility
        int createdAt
        int expiresAt
        bool isOneShot
        bool autoDestroy
        string contentType
        string storagePath
        string conditions
    }

    BOTTLECHAT {
        string messageId
        string bottleId
        string senderUserId
        string contentType
        string content
        int createdAt
    }

    BOTTLEPRESENCE {
        string userId
        int lastSeenAt
        bool isKeeper
    }

    BOTTLEWATCH {
        string userId
        string bottleId
        int createdAt
        bool notifiedOnUnlock
    }

```

Note: The actual Firebase Realtime Database schema will be tree-structured and denormalized for reads, but these entities represent the conceptual model.

------

## 3. iOS Client Responsibilities

The iOS client is responsible for user interaction and direct interaction with Firebase.

### 3.1 Responsibilities

- Handle anonymous or pseudonymous authentication via Firebase Auth.
- Read/write bottle metadata and content references in Realtime Database.
- Upload media (cover image, audio whispers, chat media) to Firebase Storage.
- Join and leave bottle chats (presence updates in Realtime Database).
- Poll or subscribe to bottle and chat updates via Realtime Database listeners.
- Display auto-translated chat messages using on-device translation frameworks.
- Manage local state for watched bottles and My Bottles.
- Register and update FCM push tokens for the current device.

### 3.2 Client-Firebase Interaction (Bottle Creation)

```mermaid
sequenceDiagram
    participant U as User (iOS)
    participant A as iOS App
    participant B as Firebase Auth
    participant C as Realtime DB
    participant D as Storage

    U->>A: Create new bottle (set rules, content)
    A->>B: Ensure authenticated user
    B-->>A: userId

    A->>D: Upload media (image/audio) if any
    D-->>A: storagePath

    A->>C: Write bottle node
        note right of C: status=locked<br/>conditions set<br/>contentType + storagePath

    C-->>A: Bottle created (bottleId)
```

------

## 4. Firebase Responsibilities

Firebase acts as the shared data and messaging backbone.

### 4.1 Auth

- Create and manage user accounts.
- Provide userId tokens to the iOS client.
- Enforce write/read rules via security rules.

### 4.2 Realtime Database

- Store bottles, chats, presence, watched bottles, and lifecycle metadata.
- Provide live subscription streams to iOS clients.
- Expose change streams for the worker service.

### 4.3 Storage

- Store media files (cover images, audio whispers, chat images/clips).
- Enforce security via storage rules (access per bottle and lifecycle).

### 4.4 Cloud Messaging (FCM)

- Deliver push notifications to iOS devices.
- Device tokens stored in DB linked to userId.

### 4.5 Optional Cloud Functions

- Lightweight triggers: e.g., send simple notifications immediately on write.
- Non-critical tasks: logging, analytics, indexing.

Critical lifecycle and survival logic remains in the Drift Worker Service, not in Functions.

------

## 5. Drift Worker Service (.NET) Responsibilities

The worker service enforces Drift’s core mechanics:

- Lifecycle rules
- Presence-based survival
- Cleanup and deletion
- Advanced notification logic

### 5.1 Internal Modules

```mermaid
flowchart TB
    subgraph Drift Worker Service
        A[Bootstrap / Host]
        B[Presence Monitor]
        C[Lifecycle Processor]
        D[Cleanup Processor]
        E[Notification Dispatcher]
        F[Rule Evaluator]
    end

    A --> B
    A --> C
    A --> D
    A --> E
    C --> F
```

### 5.2 Module Responsibilities

- Presence Monitor
  - Periodically scans presence trees for active bottles.
  - Computes for each bottle whether at least one user is inside.
  - Updates per-bottle `lastActiveAt` and `isOccupied` flags.
- Lifecycle Processor
  - Applies the bottle state machine.
  - Maintains countdown timers for bottles that have gone empty.
  - Marks bottles as `active`, `dying`, or `expired`.
  - Handles one-shot and expiration rules.
- Cleanup Processor
  - Physically removes expired bottles and associated data.
  - Deletes media from Firebase Storage.
  - Cleans chat messages and presence nodes.
- Notification Dispatcher
  - Sends push notifications through FCM.
  - Notifies creators and watchers on key events (first open, unlock, chat activity) respecting ephemeral rules.
- Rule Evaluator
  - Evaluates opening conditions for each bottle (time, weather, location-compatible flags).
  - Flags bottles as `openable` or `locked` for discovery computations.

------

## 6. Bottle Lifecycle State Machine

### 6.1 States

Possible states:

- `locked`: Conditions not yet met.
- `openable`: Conditions met; bottle can be opened.
- `active`: Bottle is open and chat is alive.
- `dying`: All users have left; death countdown started.
- `expired`: Bottle is permanently closed; ready for cleanup.

```mermaid
stateDiagram-v2
    [*] --> locked
    locked --> openable: conditions satisfied
    openable --> active: first open
    active --> dying: last user leaves
    dying --> active: user re-enters or Keep Alive
    dying --> expired: countdown finished
    active --> expired: hard expiration (time / one-shot)
    openable --> expired: expiration before first open
    expired --> [*]
```

### 6.2 Lifecycle Enforcement

Enforcement is done by the Lifecycle Processor using data in Realtime Database:

- `conditions` subtree for each bottle
- `presence` subtree for active users
- `lifecycle` subtree (timestamps, death countdown, keeper)

------

## 7. Presence and Survival Logic

### 7.1 Presence Model in Realtime Database

Example structure:

```json
"bottlePresence": {
  "{bottleId}": {
    "{userId}": {
      "lastSeenAt": 1710000000,
      "isKeeper": true
    }
  }
}
```

- iOS app periodically updates `lastSeenAt` while the user is inside the chat.
- A user explicitly leaving the chat removes their presence node.

### 7.2 Presence Evaluation Flow

```mermaid
sequenceDiagram
    participant W as Worker
    participant C as Realtime DB

    loop every N seconds
        W->>C: Fetch active bottles
        C-->>W: Bottle list with metadata
        W->>C: For each bottle, fetch presence subtree
        C-->>W: Presence snapshot
        W->>W: Compute isOccupied, lastActiveAt
        W->>C: Update lifecycle flags (active/dying)
    end
```

- If no presence is found for a previously active bottle, the worker transitions it to `dying` and records `deathStartsAt`.
- If a user comes back before countdown ends, state returns to `active`.

------

## 8. Expiration and Cleanup

### 8.1 Expiration Rules

A bottle becomes `expired` when any of the following conditions is true:

- Global time-based expiration reached (`expiresAt` <= now).
- One-shot bottle was opened and configured to self-destruct.
- Death countdown reached (no presence during countdown window).

### 8.2 Cleanup Flow

```mermaid
sequenceDiagram
    participant L as Lifecycle Processor
    participant C as Realtime DB
    participant S as Storage
    participant X as Cleanup Processor

    L->>C: Mark bottle.status = "expired"
    L->>X: Enqueue cleanup job(bottleId)

    X->>C: Read bottle metadata, contentType, storagePath
    alt has media
        X->>S: Delete storagePath and chat media blobs
        S-->>X: OK
    end

    X->>C: Remove chat subtree
    X->>C: Remove presence subtree
    X->>C: Remove watches or mark as expired
    X->>C: Finally remove or archive bottle node
```

Cleanup guarantees that:

- No residual chat logs remain.
- Media is removed from Storage.
- Watches pointing to expired bottles are updated.

------

## 9. Notifications

### 9.1 Notification Scenarios

- Bottle creator notifications
  - First bottle open
  - New user joining the chat
  - New messages while creator is away (rate-limited)
- Watcher notifications
  - Watched bottle transitions from `locked` to `openable`

Notifications are optional and respect bottle expiration (no events after `expired`).

### 9.2 Notification Flow

```mermaid
sequenceDiagram
    participant W as Worker
    participant C as Realtime DB
    participant F as FCM
    participant I as iOS App

    W->>C: Detect lifecycle or event change
    W->>C: Fetch FCM tokens of target users
    C-->>W: token list

    W->>F: Send push notification (payload with bottleId/event)
    F-->>I: Push delivered to device
    I->>C: Optional: mark notification as seen
```

The worker is responsible for:

- Deciding when to send notifications
- Avoiding duplicate notifications
- Respecting user notification preferences

------

## 10. Security and Access Control (High-Level)

- Access to bottles, chats, and presence is enforced via Firebase security rules.
- Only authenticated users can:
  - Create bottles
  - Join chats
  - Write messages
  - Watch bottles
- Workers authenticate using Firebase Admin SDK and have elevated rights restricted to server-side operations.
- Storage access is restricted to:
  - Bottle owners for creation
  - Bottle participants for reading while the bottle is active

Detailed security rules will be defined in a dedicated document.

------

## 11. Deployment Model

### 11.1 iOS App

- Distributed via the App Store.
- Configured with Firebase project credentials.

### 11.2 Firebase Project

- Single project holding Auth, Realtime DB, Storage, and FCM.
- Optional Cloud Functions for lightweight tasks.

### 11.3 Worker Service

- Deployed on Linux as a long-running service (e.g., systemd).
- Uses:
  - Firebase Admin SDK for Realtime DB, Storage, and FCM
  - Configurable polling intervals for presence and lifecycle
  - Internal timers for countdown logic

```mermaid
flowchart LR
    A[iOS App] --> B[Firebase Project]
    C[Worker Service .NET] --> B

    subgraph Server
        C
    end

    subgraph Cloud
        B
    end

    subgraph Devices
        A
    end

```

------

## 12. Summary

- iOS + Firebase cover storage, auth, and push delivery.
- The Drift Worker Service is mandatory for enforcing:
  - Bottle lifecycle
  - Presence-based survival
  - Cleanup and media deletion
  - Advanced notification scenarios

This architecture locks in the separation of concerns between:

- Client interaction
- Da