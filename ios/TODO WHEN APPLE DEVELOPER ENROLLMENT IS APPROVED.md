## **TODO WHEN APPLE DEVELOPER ENROLLMENT IS APPROVED**







### **1. Refresh Xcode account status**





- Xcode → Settings → Accounts
- Select your Apple ID
- Click “Manage Certificates…” then close the dialog
- Confirm your team now shows **Membership: Apple Developer Program**





(No need to re-add the Apple ID.)



------





### **2. Link Drift target to your Dev Team**





In Xcode, project “Drift”:



- Target → Drift → Signing & Capabilities
- Team: select your **Apple Developer Program team** (not Personal Team)
- Confirm Bundle ID: pro.aedev.Drift





------





### **3. Create APNs Auth Key (.p8)**





- Go to: https://developer.apple.com/account/resources/authkeys/list
- Create new key with APNs
- Download .p8 file
- Note the **Key ID** and **Team ID**





------





### **4. Upload APNs key to Firebase**





Firebase Console → Project Settings → Cloud Messaging → iOS app config:



- Upload **.p8**
- Enter **Key ID** and **Team ID**
- Save





------





### **5. Enable push capabilities in Xcode**





In Xcode, Drift target → Signing & Capabilities:



- Add **Push Notifications**
- Add **Background Modes** → enable **Remote notifications**





------





### **6. Verify App ID in Apple Developer**





Developer Console → Identifiers:



- Make sure there is an App ID for pro.aedev.Drift
- Push Notifications must be enabled





(Xcode may have created it automatically, just confirm.)



------





### **7. Test archive**





In Xcode:



- Product → Archive
- Ensure archive succeeds with your new team and signing





(No need to upload to TestFlight yet.)



------





### **8. Test FCM push**





Once the app runs on a real device:



- Get an FCM token from the app
- In Firebase Console → Cloud Messaging → Send test
- Send a test push to the device token
- Confirm notification arrives