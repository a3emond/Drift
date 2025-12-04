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
