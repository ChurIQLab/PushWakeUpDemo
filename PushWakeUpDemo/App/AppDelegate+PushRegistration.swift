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

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                EventLog.add(granted ? "Уведомления разрешены" : "Уведомления запрещены",
                             details: error?.localizedDescription)
            }
        }

        // Регистрация в APNs не зависит от разрешения: токен выдаётся в любом случае,
        // но без разрешения iOS не покажет пуш пользователю.
        application.registerForRemoteNotifications()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        EventLog.add("APNs-токен получен", details: "Дальше Firebase выдаст FCM-токен")
    }

    /// Если здесь ошибка — FCM-токена не будет. Обычно причина в подписи
    /// (нет Push Notifications в профиле) или это симулятор без поддержки APNs.
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        EventLog.add("Ошибка регистрации в APNs", details: error.localizedDescription)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        DispatchQueue.main.async {
            guard let fcmToken, fcmToken != FCMTokenStore.current else { return }
            FCMTokenStore.current = fcmToken
            EventLog.add("FCM-токен получен", details: "По нему сервер отправляет пуш")
        }
    }
}
