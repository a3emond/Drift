# **Firebase Storage Rules for Drift**



```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // ------------------------------------------------------
    // User Avatars
    // ------------------------------------------------------
    match /users/{uid}/{fileName} {
      allow read: if request.auth != null; // all authenticated users may read avatars
      allow write: if request.auth != null && request.auth.uid == uid; // only owner may write
    }

    // ------------------------------------------------------
    // Bottle Content Media
    // bottles/{bottleId}/content/{fileName}
    // ------------------------------------------------------
    match /bottles/{bottleId}/content/{fileName} {
      allow read: if request.auth != null;
      allow write: if isBottleOwner(bottleId);
    }

    // ------------------------------------------------------
    // Bottle Chat Media
    // bottles/{bottleId}/chat/{messageId}/{fileName}
    // ------------------------------------------------------
    match /bottles/{bottleId}/chat/{messageId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if isChatParticipant(bottleId);
    }

    // ------------------------------------------------------
    // Helper Functions
    // These rely on the Realtime Database to validate roles.
    // ------------------------------------------------------
    function isBottleOwner(bottleId) {
      return get(/databases/(default)/documents/bottles/$(bottleId)).data.owner_uid == request.auth.uid;
    }

    function isChatParticipant(bottleId) {
      return get(/databases/(default)/documents/bottles/$(bottleId)/chat_participants/$(request.auth.uid)).exists();
    }
  }
}
```