# **Drift – Firebase Storage Architecture**







## **1. Scope and Objectives**





This document defines how Drift uses **Firebase Storage** to store and manage all binary media:



- Bottle content media (image and audio whisper)
- Chat media (images and audio)
- User avatar images





It also establishes the **conventions the iOS client must follow** and what needs to be configured in **Firebase Console**. Security rules are defined in a separate file and are not covered here.



------





## **2. Bucket Overview**





Drift uses a single Firebase Storage bucket (the default bucket created with the Firebase project).



Logical top-level prefixes:



- bottles/ – all media directly tied to a bottle
- users/ – user-specific avatar media





Firebase Storage does not require folders to be pre-created; the structure is defined by the paths used when uploading objects.



------





## **3. Path Structure**







### **3.1 Bottle Content Media**





Path pattern:

```
bottles/{bottleId}/content/{fileName}
```

Intended usage:



- message_image.jpg – main image associated with the bottle (if any)
- whisper.m4a – short audio whisper associated with the bottle (if any)





Examples:

```
bottles/3fj9adZkP3t/content/message_image.jpg
bottles/3fj9adZkP3t/content/whisper.m4a
```

Notes:



- Each bottle has at most a small set of files in content/.
- These files are deleted when the bottle expires or is killed by the worker.





------





### **3.2 Bottle Chat Media**





Path pattern:

```
bottles/{bottleId}/chat/{messageId}/{fileName}
```

Intended usage:



- image.jpg – image attached to a chat message
- audio.m4a – audio snippet attached to a chat message





Examples:

```
bottles/3fj9adZkP3t/chat/msg_001/image.jpg
bottles/3fj9adZkP3t/chat/msg_001/audio.m4a
bottles/3fj9adZkP3t/chat/msg_002/image.jpg
```

Notes:



- Each chat message has its own prefix: bottles/{bottleId}/chat/{messageId}/.
- This keeps media isolated per message and simplifies targeted deletion.
- When a bottle is permanently closed or expires, the worker deletes the entire bottles/{bottleId}/ subtree.





------





### **3.3 User Avatars**





Path pattern:

```
users/{uid}/avatar.png
```

Intended usage:



- Single avatar per user, updated over time.





Example:

```
users/uid_123/avatar.png
```

Notes:



- Avatar size should be kept small (for example, under 50 KB) to keep bandwidth and storage low.
- Avatar files are not tied to bottle lifecycle and are **not** deleted when bottles expire.





------





### **3.4 Summary Tree**





Conceptual tree (logical, not physically pre-created):

```
bottles/
  {bottleId}/
    content/
      message_image.jpg
      whisper.m4a
    chat/
      {messageId}/
        image.jpg
        audio.m4a

users/
  {uid}/
    avatar.png
```



------





## **4. Firebase Console Setup – Storage**





To prepare the Storage environment for Drift:



1. **Enable Firebase Storage** (already done when creating the project).

2. Use the **default bucket** created by Firebase. There is no need to create extra buckets for now.

3. No manual folder creation is required; the iOS app and worker will implicitly create paths by uploading objects.

4. Configure Storage security rules in a dedicated Storage rules file (separate from this document). Rules will:

   

   - Allow authenticated users to upload avatars under users/{uid}/.
   - Allow authenticated bottle owners to upload bottle content under bottles/{bottleId}/content/.
   - Allow authenticated chat participants to upload chat media under bottles/{bottleId}/chat/{messageId}/.
   - Restrict direct access to any other paths.

   





The precise rules syntax will be handled in the Storage rules file; this document only defines paths and responsibilities.



------





## **5. iOS Client Conventions**





This section defines how the iOS app must interact with Firebase Storage.





### **5.1 General Rules**





- The iOS app **must never write outside** the defined prefixes:

  

  - users/{uid}/avatar.png
  - bottles/{bottleId}/content/...
  - bottles/{bottleId}/chat/{messageId}/...

  

- All Storage references should be built using the **canonical patterns** in this document.

- All uploads must set an appropriate **MIME type** (for example, image/jpeg, image/png, audio/m4a).

- The app should store **only Storage paths** (not download URLs) in the Realtime Database:

  

  - Example: content.image_path = "bottles/{bottleId}/content/message_image.jpg".
  - At display time, the client resolves these paths into Storage references.

  





This avoids having to rotate or invalidate long-lived download URLs.



------





### **5.2 Avatars (iOS)**





- When a user selects or updates an avatar, the app:

  

  1. Compresses and normalizes the image (size and format).
  2. Uploads to users/{uid}/avatar.png with contentType = image/png.
  3. Optionally updates the settings.avatar_style or related fields in /users/{uid}.

  





The app should never rely on avatar.png being public; it should always obtain it via Firebase Storage SDK using the authenticated user.



------





### **5.3 Bottle Content Media (iOS)**





- When creating or editing a bottle with media:

  

  1. Generate or obtain a bottleId (created in Realtime Database first).

  2. If there is a main image, upload to:

     

     - bottles/{bottleId}/content/message_image.jpg

     

  3. If there is a whisper audio, upload to:

     

     - bottles/{bottleId}/content/whisper.m4a

     

  4. Store the paths in the bottle content node in the database:

     

     - content.image_path = "bottles/{bottleId}/content/message_image.jpg"
     - content.audio_path = "bottles/{bottleId}/content/whisper.m4a"

     

  

- The iOS app must not create additional arbitrary file names; use standard names unless there is a clear need to change them.





------





### **5.4 Chat Media (iOS)**





- For each chat message that contains media:

  

  1. Obtain the bottleId and a unique messageId (from the database push key).
  2. Build a Storage path prefix:

  



```
bottles/{bottleId}/chat/{messageId}/
```



- 

  1. 

  2. For image content:

     

     - Upload to bottles/{bottleId}/chat/{messageId}/image.jpg with contentType = image/jpeg.

     

  3. For audio content:

     

     - Upload to bottles/{bottleId}/chat/{messageId}/audio.m4a with contentType = audio/m4a.

     

  4. Store the relative paths in the chat message node:

     

     - image_path = "bottles/{bottleId}/chat/{messageId}/image.jpg"
     - audio_path = "bottles/{bottleId}/chat/{messageId}/audio.m4a"

     

  

- If a message has both image and audio, both files coexist under the same prefix.





------





### **5.5 Media Display (iOS)**





- To display an avatar, bottle image, or chat media:

  

  1. Read the Storage path from the database.

  2. Build a StorageReference using the Firebase iOS SDK.

  3. Either:

     

     - Download the data directly (for small images/audio), or
     - Obtain a download URL and hand it to the relevant system player or image loader.

     

  

- The iOS app must handle transient errors (network issues, permission changes) gracefully and avoid assuming that media is always available.





------





## **6. Worker Responsibilities**





The Drift Worker service will run with Firebase Admin credentials and is responsible for:



1. **Bottle Lifecycle Cleanup**

   

   - When a bottle expires or is marked dead in the database, the worker deletes:

   



```
bottles/{bottleId}/...
```



1. 

   - 
   - This removes all content and chat media for that bottle.

   

2. **Chat-Specific Cleanup (Optional)**

   

   - The worker may run periodic cleanup of old chat media if additional policies are introduced (for example, maximum chat size or time-based retention inside still-alive bottles).

   

3. **Avatar Cleanup (Optional)**

   

   - If a user deletes their account, the worker may delete users/{uid}/avatar.png.

   





The iOS client **never** performs destructive bulk operations on Storage; only the worker is responsible for global cleanup.



------





## **7. Testing Checklist**





Before going further with implementation, the following tests should be planned and executed:



1. **Avatar Flow**

   

   - Upload a new avatar.
   - Confirm that the file appears under users/{uid}/avatar.png.
   - Confirm the app can read and display it.

   

2. **Bottle Creation with Media**

   

   - Create a bottle with an image and/or audio.
   - Verify files appear under bottles/{bottleId}/content/.
   - Confirm the DB content node contains the correct Storage paths.

   

3. **Chat Media**

   

   - Send chat messages with images and audio.
   - Verify files appear under bottles/{bottleId}/chat/{messageId}/.
   - Confirm message nodes contain correct image_path / audio_path.

   

4. **Worker Cleanup (when implemented)**

   

   - Force a bottle to expire or be killed.
   - Confirm the worker deletes all bottles/{bottleId}/ media.
   - Ensure the app handles missing media gracefully after deletion.

   





Once these behaviors are validated, Storage integration can be considered stable enough to support higher-level features (UI, survival mechanics, and monetization-related media).