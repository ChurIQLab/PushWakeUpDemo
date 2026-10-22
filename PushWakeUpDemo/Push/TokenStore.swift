import Foundation

/// Токены, по которым сервер отправляет пуши на это устройство.
enum PushToken: CaseIterable {
    case fcm   // обычные пуши — сервер отправляет через Firebase
    case voip  // VoIP-пуши (PushKit) — сервер отправляет в APNs напрямую, без Firebase

    var title: String {
        switch self {
        case .fcm: return "FCM-токен"
        case .voip: return "VoIP-токен"
        }
    }

    /// Префикс строки в консоли Xcode: FCM_TOKEN=… / VOIP_TOKEN=…
    var consolePrefix: String {
        switch self {
        case .fcm: return "FCM_TOKEN"
        case .voip: return "VOIP_TOKEN"
        }
    }

    fileprivate var storageKey: String {
        switch self {
        case .fcm: return "fcm_token"
        case .voip: return "voip_token"
        }
    }
}

/// Хранит последние токены, чтобы показать их на главном экране.
/// В реальном приложении в этот момент токены отправляют на свой сервер.
enum TokenStore {
    static let didChangeNotification = Notification.Name("TokenStoreDidChange")

    static func token(_ kind: PushToken) -> String? {
        UserDefaults.standard.string(forKey: kind.storageKey)
    }

    /// Возвращает true, если токен новый (не совпал с сохранённым).
    @discardableResult
    static func save(_ token: String?, for kind: PushToken) -> Bool {
        let isNew = token != self.token(kind)
        UserDefaults.standard.set(token, forKey: kind.storageKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        if let token {
            // Отдельной строкой — чтобы при запуске из Xcode скопировать токен прямо из консоли.
            print("\(kind.consolePrefix)=\(token)")
        }
        return isNew
    }
}
