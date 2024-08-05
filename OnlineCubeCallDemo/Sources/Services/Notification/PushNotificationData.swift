import Foundation

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
}
