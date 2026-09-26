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
            EventLog.add("Пуш пришёл при открытом приложении",
                         details: "Показываем баннер. Payload: \(Self.describe(userInfo))")
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
                EventLog.add("Нажали на пуш, но это не звонок", details: "Payload: \(Self.describe(userInfo))")
                return
            }
            guard let callData = PushNotificationData(userInfo: userInfo) else {
                EventLog.add("Не удалось разобрать payload", details: Self.describe(userInfo))
                return
            }

            EventLog.add("Нажали на пуш звонка", details: "Открываем предпросмотр. Домофон: \(callData.addr)")
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

    /// Payload одной строкой для журнала (без `aps`).
    private static func describe(_ userInfo: [AnyHashable: Any]) -> String {
        userInfo
            .filter { $0.key as? String != "aps" }
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: ", ")
    }
}
