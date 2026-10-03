import UIKit
import UserNotifications

/// Реакция на пуши.
///
/// Главное, что показывает демо: обычный пуш сам приложение не будит.
/// - Приложение открыто → iOS спрашивает `willPresent`, как показать пуш.
/// - Приложение свёрнуто или убито → пуш показывает iOS, приложение ничего не знает.
/// - Пользователь нажал на пуш → iOS запускает приложение (если оно было убито)
///   и передаёт payload в `didReceive`.
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

    /// Пользователь нажал на пуш.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        DispatchQueue.main.async {
            defer { completionHandler() }

            guard NotificationType(userInfo: userInfo) == .sipCall else {
                EventLog.add(.warning, "Нажали на пуш, но это не звонок", details: Self.describe(userInfo))
                return
            }
            guard let callData = PushNotificationData(userInfo: userInfo) else {
                EventLog.add(.error, "Не удалось разобрать payload", details: Self.describe(userInfo))
                return
            }

            EventLog.add(.tap, "Нажали на пуш звонка", details: "Открываем предпросмотр. Домофон: \(callData.addr)")
            self.showCallPreview(with: callData)
        }
    }

    // MARK: - Экран предпросмотра

    /// При холодном старте `didReceive` приходит, пока приложение ещё неактивно
    /// и главный экран не успел появиться — `present` в этот момент молча не срабатывает.
    /// Поэтому запоминаем звонок и показываем экран, когда приложение станет активным.
    private func showCallPreview(with callData: PushNotificationData) {
        pendingCallPreview = callData
        if UIApplication.shared.applicationState == .active {
            presentPendingCallPreview()
        }
    }

    func presentPendingCallPreview() {
        guard let callData = pendingCallPreview else { return }
        pendingCallPreview = nil

        var topViewController = window?.rootViewController
        while let presented = topViewController?.presentedViewController {
            topViewController = presented
        }
        let preview = UINavigationController(rootViewController: CallPreviewViewController(callData: callData))
        topViewController?.present(preview, animated: true)
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
