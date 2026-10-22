import PushKit

/// PushKit — VoIP-пуши.
///
/// - Будят приложение СРАЗУ, без участия пользователя: даже если приложение смахнули
///   из многозадачности и даже если уведомления запрещены.
/// - Взамен iOS требует на каждый VoIP-пуш сразу показать звонок через CallKit
///   (`reportNewIncomingCall`) до вызова `completion`. Иначе iOS убьёт приложение,
///   а после нескольких нарушений перестанет доставлять ему VoIP-пуши.
/// - Firebase VoIP-пуши не отправляет: сервер шлёт их в APNs напрямую
///   (topic `<bundle id>.voip`, `apns-push-type: voip`) — см. `Scripts/send_voip_push.sh`.
final class VoIPPushService: NSObject {

    /// Пришёл VoIP-пуш. Обработчик обязан зарепортить звонок в CallKit и вызвать completion.
    var onIncomingCall: ((PushNotificationData, _ completion: @escaping () -> Void) -> Void)?

    private let registry = PKPushRegistry(queue: .main)

    /// Вызывать в `didFinishLaunching` при КАЖДОМ запуске: если приложение запустил
    /// VoIP-пуш, iOS отдаст его только после того, как реестр создан и делегат назначен.
    func start() {
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
    }
}

// MARK: - PKPushRegistryDelegate

extension VoIPPushService: PKPushRegistryDelegate {

    /// VoIP-токен — отдельный от APNs- и FCM-токена. Сервер шлёт VoIP-пуш именно на него.
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        let isNew = TokenStore.save(token, for: .voip)
        EventLog.add(.token, isNew ? "VoIP-токен получен (новый)" : "VoIP-токен получен (не изменился)", details: token)
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        TokenStore.save(nil, for: .voip)
        EventLog.add(.warning, "VoIP-токен больше не действует")
    }

    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType,
                      completion: @escaping () -> Void) {
        let userInfo = payload.dictionaryPayload
        EventLog.add(.voip, "VoIP-пуш разбудил приложение", details: PushNotificationData.describe(userInfo))

        // Даже если payload странный — звонок в CallKit показать всё равно обязаны.
        let callData = PushNotificationData(userInfo: userInfo) ?? PushNotificationData(userInfo: ["addr": "?"])!
        if NotificationType(userInfo: userInfo) != .sipCall {
            EventLog.add(.warning, "VoIP-пуш без type = sip_call", details: "CallKit всё равно показываем — так требует iOS")
        }

        guard let onIncomingCall else {
            completion()
            return
        }
        onIncomingCall(callData, completion)
    }
}
