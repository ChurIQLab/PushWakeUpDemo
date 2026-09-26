import Foundation

/// Хранит последний FCM-токен, чтобы показать его на главном экране.
/// В реальном приложении в этот момент токен отправляют на свой сервер.
enum FCMTokenStore {
    static let didChangeNotification = Notification.Name("FCMTokenDidChange")

    private static let key = "fcm_token"

    static var current: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }
}
