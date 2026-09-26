import Foundation

/// Данные звонка из пуша. FCM кладёт поля из `data` в корень userInfo, рядом с `aps`.
struct PushNotificationData: Codable {
    let serviceURL: String
    let paneleID: String
    let asteriskURL: String
    let addr: String
    let rtsp: String
    let type: String
    let token: String
    let callID: String

    enum CodingKeys: String, CodingKey {
        case serviceURL = "service_url"
        case paneleID = "panele_id"
        case asteriskURL = "asterisk_url"
        case addr
        case rtsp
        case type
        case token
        case callID = "call_id"
    }

    /// Отсутствующее поле не ломает разбор — пуш всё равно должен открыться.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        serviceURL = try container.decodeIfPresent(String.self, forKey: .serviceURL) ?? ""
        paneleID = try container.decodeIfPresent(String.self, forKey: .paneleID) ?? ""
        asteriskURL = try container.decodeIfPresent(String.self, forKey: .asteriskURL) ?? ""
        addr = try container.decodeIfPresent(String.self, forKey: .addr) ?? ""
        rtsp = try container.decodeIfPresent(String.self, forKey: .rtsp) ?? ""
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        token = try container.decodeIfPresent(String.self, forKey: .token) ?? ""
        callID = try container.decodeIfPresent(String.self, forKey: .callID) ?? ""
    }

    /// Берём только строковые поля: `aps` и служебные ключи FCM нам не нужны.
    init?(userInfo: [AnyHashable: Any]) {
        let strings = userInfo.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String {
                result[key] = value
            }
        }
        guard let json = try? JSONSerialization.data(withJSONObject: strings),
              let decoded = try? JSONDecoder().decode(PushNotificationData.self, from: json) else {
            return nil
        }
        self = decoded
    }
}
