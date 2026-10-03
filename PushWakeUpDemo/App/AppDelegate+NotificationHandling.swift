import UIKit
import UserNotifications

/// Реакция на пуши.
///
/// Главное, что показывает демо: обычный пуш сам приложение не будит.
/// - Приложение открыто → iOS спрашивает `willPresent`, как показать пуш.
/// - Приложение свёрнуто или убито → пуш показывает iOS, приложение ничего не знает.
/// - Пользователь что-то сделал с пушем (нажал, нажал кнопку, смахнул) → iOS запускает
///   приложение, если оно было убито, и передаёт действие и payload в `didReceive`.
extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Пуш пришёл, когда приложение открыто. Экран не открываем —
    /// просим iOS показать баннер, как если бы приложение было в фоне.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        DispatchQueue.main.async {
            EventLog.add(.push, "Пуш пришёл при открытом приложении",
                         details: "Показываем баннер\n\(Self.describe(userInfo))")
            completionHandler([.banner, .list, .badge, .sound])
        }
    }

    /// Пользователь что-то сделал с пушем. Что именно — в `response.actionIdentifier`.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        DispatchQueue.main.async {
            // completionHandler сообщает iOS, что приложение закончило обработку.
            // Для действий в фоне после этого iOS может снова усыпить приложение.
            defer { completionHandler() }

            guard NotificationType(userInfo: userInfo) == .sipCall else {
                EventLog.add(.warning, "Действие с пушем, но это не звонок", details: Self.describe(userInfo))
                return
            }
            guard let callData = PushNotificationData(userInfo: userInfo) else {
                EventLog.add(.error, "Не удалось разобрать payload", details: Self.describe(userInfo))
                return
            }

            switch response.actionIdentifier {
            case UNNotificationDefaultActionIdentifier:
                // Обычное нажатие на пуш
                EventLog.add(.tap, "Нажали на пуш звонка", details: "Открываем предпросмотр. Домофон: \(callData.addr)")
                self.showCallPreview(with: callData, origin: .tap)

            case CallNotificationCategory.Action.answer:
                // Кнопка с .foreground — iOS уже открывает приложение
                EventLog.add(.answer, "Нажали «Ответить» в пуше", details: "Открываем предпросмотр. Домофон: \(callData.addr)")
                self.showCallPreview(with: callData, origin: .answer)

            case CallNotificationCategory.Action.decline:
                // Кнопка без .foreground — приложение разбужено в фоне, экран не показываем.
                // В реальном приложении здесь сообщаем серверу, что звонок отклонён.
                EventLog.add(.decline, "Нажали «Отклонить» в пуше",
                             details: "Приложение разбужено в фоне, экран не открывается. Домофон: \(callData.addr)")

            case UNNotificationDismissActionIdentifier:
                // Пуш смахнули. Приходит только благодаря .customDismissAction у категории.
                EventLog.add(.dismiss, "Пуш смахнули",
                             details: "Приложение разбужено в фоне, экран не открывается. Домофон: \(callData.addr)")

            default:
                EventLog.add(.warning, "Неизвестное действие с пушем", details: response.actionIdentifier)
            }
        }
    }

    // MARK: - Экран предпросмотра

    /// При холодном старте `didReceive` приходит, пока приложение ещё неактивно
    /// и главный экран не успел появиться — `present` в этот момент молча не срабатывает.
    /// Поэтому запоминаем звонок и показываем экран, когда приложение станет активным.
    private func showCallPreview(with callData: PushNotificationData, origin: CallPreviewViewController.Origin) {
        pendingCallPreview = (callData, origin)
        if UIApplication.shared.applicationState == .active {
            presentPendingCallPreview()
        }
    }

    func presentPendingCallPreview() {
        guard let (callData, origin) = pendingCallPreview else { return }
        pendingCallPreview = nil

        var topViewController = window?.rootViewController
        while let presented = topViewController?.presentedViewController {
            topViewController = presented
        }
        let preview = CallPreviewViewController(callData: callData, origin: origin)
        topViewController?.present(UINavigationController(rootViewController: preview), animated: true)
    }

    /// Поля payload для журнала — по одному на строку. Без `aps` (это текст пуша для iOS)
    /// и служебных ключей Firebase и simctl.
    private static func describe(_ userInfo: [AnyHashable: Any]) -> String {
        let serviceKeys = ["aps", "Simulator Target Bundle", "fcm_options"]
        return userInfo
            .compactMap { key, value -> String? in
                guard let key = key as? String,
                      !serviceKeys.contains(key),
                      !key.hasPrefix("gcm."), !key.hasPrefix("google.") else { return nil }
                return "\(key): \(value)"
            }
            .sorted()
            .joined(separator: "\n")
    }
}
