import UIKit
import Firebase
import FirebaseMessaging
import CoreLocation
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Enable verbose logging for Firebase
        FirebaseConfiguration.shared.setLoggerLevel(.debug)
        FirebaseApp.configure()
        
        // Initialize and set up the LocationManager for location services
        LocationManager.shared.requestLocationAuthorization()
        
        // Request push notification authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print("Push notification authorization granted: \(granted)")
        }
        application.registerForRemoteNotifications()
        
        // Configure Firebase Messaging
        Messaging.messaging().delegate = self
        
        // Create the window
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // Load the storyboard
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        // Instantiate the initial view controller
        let initialViewController = storyboard.instantiateInitialViewController()
        
        // Set the initial view controller as the root view controller
        window?.rootViewController = initialViewController
        window?.makeKeyAndVisible()
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
    }

    // MARK: Push Notifications

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device APNs Token: \(token)")
        
        // Ensure APNs token is correctly set
        Auth.auth().setAPNSToken(deviceToken, type: .sandbox) // Change to .prod for production
        
        // Retrieve FCM token
        Messaging.messaging().token { token, error in
            if let error = error {
                print("Error fetching FCM token: \(error)")
            } else if let token = token {
                print("FCM Token: \(token)")
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        // Handle other types of notifications here
    }

    // MARK: URL Scheme Handling

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        // Handle other custom URL schemes here
        return false
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let fcmToken = fcmToken {
            print("Firebase registration token: \(fcmToken)")
        } else {
            print("Failed to fetch FCM token")
        }
    }
}
