import UIKit
import FirebaseCore
import FirebaseMessaging

/// Регистрация для пушей. Цепочка такая:
/// 1. Просим у пользователя разрешение показывать уведомления.
/// 2. Регистрируемся в APNs → iOS отдаёт APNs-токен устройства.
/// 3. Firebase обменивает APNs-токен на FCM-токен.
/// 4. FCM-токен отдаём серверу — по нему сервер шлёт пуш через Firebase.
extension AppDelegate: MessagingDelegate {

    func configurePushNotifications(for application: UIApplication) {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        CallNotificationCategory.register()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                EventLog.add(granted ? .permission : .warning, granted ? "Уведомления разрешены" : "Уведомления запрещены",
                             details: error?.localizedDescription)
            }
        }

        // Регистрация в APNs не зависит от разрешения: токен выдаётся в любом случае,
        // но без разрешения iOS не покажет пуш пользователю.
        application.registerForRemoteNotifications()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        EventLog.add(.token, "APNs-токен получен", details: "\(token)\nДальше Firebase выдаст FCM-токен")
    }

    /// Если здесь ошибка — FCM-токена не будет. Обычно причина в подписи
    /// (нет Push Notifications в профиле) или это симулятор без поддержки APNs.
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        EventLog.add(.error, "Ошибка регистрации в APNs", details: error.localizedDescription)
    }

    /// Firebase вызывает это при каждом запуске, а не только когда токен сменился.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        DispatchQueue.main.async {
            guard let fcmToken else { return }
            let isNew = fcmToken != FCMTokenStore.current
            FCMTokenStore.current = fcmToken
            EventLog.add(.token, isNew ? "FCM-токен получен (новый)" : "FCM-токен получен (не изменился)", details: fcmToken)

            // Отдельной строкой — чтобы при запуске из Xcode скопировать токен прямо из консоли.
            print("FCM_TOKEN=\(fcmToken)")
        }
    }
}
