import Foundation

/// Значение поля `type` из `data` пуша.
enum NotificationType: String {
    case sipCall = "sip_call"

    init?(userInfo: [AnyHashable: Any]) {
        guard let rawValue = userInfo["type"] as? String else { return nil }
        self.init(rawValue: rawValue)
    }
}
