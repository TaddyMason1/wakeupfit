import SwiftUI
import UserNotifications

@main
struct WakeUpFitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            AlarmListView()
        }
    }
}

// MARK: - App Delegate for Notification Handling

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    // Called when a notification is delivered while the app is in the FOREGROUND
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the banner + play the sound even if the app is open
        completionHandler([.banner, .sound])
        
        // Post a notification so our UI can react and launch the workout
        NotificationCenter.default.post(name: .alarmFired, object: nil)
    }
    
    // Called when the user TAPS the notification (app was in background)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Post a notification so our UI can react and launch the workout
        NotificationCenter.default.post(name: .alarmFired, object: nil)
        completionHandler()
    }
}

extension Notification.Name {
    static let alarmFired = Notification.Name("wakeUpFit_alarmFired")
}
