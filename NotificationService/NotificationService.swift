import UserNotifications

/// Notification Service Extension — отдельный маленький процесс, который iOS запускает
/// на каждый пуш с `"mutable-content": 1` ДО того, как показать его пользователю.
///
/// - Работает, даже если приложение убито. Само приложение при этом НЕ просыпается.
/// - На изменение пуша есть около 30 секунд, потом iOS вызовет `serviceExtensionTimeWillExpire`.
/// - Без `"mutable-content": 1` в `aps` расширение не вызывается вообще.
final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        EventLog.stateProvider = { "расширение · отдельный процесс, приложение не будится" }
        self.contentHandler = contentHandler

        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        bestAttemptContent = content

        // Не звонок — показываем как пришёл
        guard NotificationType(userInfo: content.userInfo) == .sipCall,
              let callData = PushNotificationData(userInfo: content.userInfo) else {
            contentHandler(content)
            return
        }

        let original = [content.title, content.body].filter { !$0.isEmpty }.joined(separator: " / ")
        decorateAsIncomingCall(content, callData: callData)

        EventLog.add(.serviceExtension, "Расширение изменило пуш",
                     details: "Было: \(original)\nСтало: \(content.title) / \(content.subtitle)\nКатегория с кнопками, неотложный, звук customSound.wav")
        contentHandler(content)
    }

    /// iOS вот-вот покажет пуш как есть — отдаём то, что успели изменить.
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func decorateAsIncomingCall(_ content: UNMutableNotificationContent, callData: PushNotificationData) {
        content.title = "📞 Входящий звонок"
        content.subtitle = callData.addr.isEmpty ? "Домофон" : "Домофон: \(callData.addr)"
        content.body = "Зажмите, чтобы ответить или отклонить"

        // Кнопки «Ответить» / «Отклонить» появятся, даже если сервер не прислал category
        content.categoryIdentifier = CallNotificationCategory.identifier

        // Звук ищется в бандле приложения (Resources/Sounds)
        content.sound = UNNotificationSound(named: UNNotificationSoundName("customSound.wav"))

        // Неотложный пуш пробивает «Не беспокоить» и фокус. Нужен entitlement
        // com.apple.developer.usernotifications.time-sensitive у приложения.
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1

        // Пуши одного звонка собираются в одну стопку
        content.threadIdentifier = "call-\(callData.callID)"

        // Метка для приложения: в журнале будет видно, что пуш прошёл через расширение
        content.userInfo["nse_modified"] = "1"
    }
}
