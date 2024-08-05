import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    private var loaderView: LoaderView?
    private var callData: PushNotificationData?

    lazy var sipService: SIPService? = {
        guard let callData = callData else {
            print("Error: Call data must be provided before accessing SIPService.")
            return nil        }
        return SIPService(callData: callData)
    }()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("App launched")

        let rootViewController = MainViewController()
        let navigationController = UINavigationController(rootViewController: rootViewController)

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.makeKeyAndVisible()
        window?.rootViewController = navigationController

        configureFirebase(for: application)
        return true
    }
}

// MARK: - Configure Firebase

extension AppDelegate: MessagingDelegate {
    private func configureFirebase(for application: UIApplication) {
        print("Configuring Firebase")
        FirebaseApp.configure()

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions, completionHandler: { granted, error in
            print("Authorization granted: \(granted), error: \(String(describing: error))")
        })

        application.registerForRemoteNotifications()
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Received Firebase registration token: \(String(describing: fcmToken))")

        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
    }
}

// MARK: - Push Notification

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
    -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        print("Notification will present: \(userInfo)")

        guard let typeString = userInfo["type"] as? String,
              let type = NotificationType(rawValue: typeString) else {
            print("Invalid or missing type in notification")
            return [.banner, .badge, .sound]
        }

        switch type {
        case .sipCall:
            handleSipCallNotification(userInfo)
        }

        return [.banner, .badge, .sound]
    }


    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        print("Notification did receive: \(userInfo)")

        guard let typeString = userInfo["type"] as? String, let type = NotificationType(rawValue: typeString) else {
            print("Invalid or missing type in notification")
            return
        }

        switch type {
        case .sipCall:
            handleSipCallNotification(userInfo)
        }
    }
}

// MARK: - Loader Management

extension AppDelegate {
    func showLoader() {
        print("Showing loader")
        guard loaderView == nil else { return }
        let loader = LoaderView(frame: window?.bounds ?? UIScreen.main.bounds)
        window?.addSubview(loader)
        loader.startAnimating()
        loaderView = loader
    }

    func removeLoader() {
        print("Removing loader")
        loaderView?.stopAnimating()
        loaderView?.removeFromSuperview()
        loaderView = nil
    }
}

// MARK: - Incoming Call Handling

extension AppDelegate {
    func handleIncomingCall(with callData: PushNotificationData) {
        print("Handling incoming call with data: \(callData)")
        self.callData = callData
        showLoader()

        guard let sipService = sipService else {
            print("SIPService is not initialized")
            removeLoader()
            return
        }

        sipService.startService() { [weak self] in
            print("SIP service started")
            self?.removeLoader()
            self?.showCallScreen(with: callData)
        }
    }

    func showCallScreen(with callData: PushNotificationData) {
        print("Showing call screen with data")
        let incomingCallViewController = IncomingCallViewController()
        incomingCallViewController.setup(with: callData)
        window?.rootViewController?.present(incomingCallViewController, animated: true, completion: nil)
    }
}

// MARK: - Notification Data Handling

extension AppDelegate {
    private func handleSipCallNotification(_ userInfo: [AnyHashable: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: userInfo, options: []) else {
            print("Failed to serialize userInfo")
            return
        }

        do {
            let callData = try JSONDecoder().decode(PushNotificationData.self, from: jsonData)
            handleIncomingCall(with: callData)
        } catch {
            print("Failed to decode PushNotificationData: \(error.localizedDescription)")
        }
    }
}
