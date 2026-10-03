import UIKit

/// Точка входа. Вся логика пушей разнесена по расширениям:
/// - `AppDelegate+PushRegistration.swift` — разрешение, APNs-токен, FCM-токен;
/// - `AppDelegate+NotificationHandling.swift` — что делать, когда пуш пришёл и когда по нему нажали.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    /// Звонок, по пушу которого нажали, но экран ещё нельзя показать (приложение не активно).
    var pendingCallPreview: (PushNotificationData, CallPreviewViewController.Origin)?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        EventLog.markLaunch()
        EventLog.add(.launch, "Приложение запущено")

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: MainViewController())
        window?.makeKeyAndVisible()

        // Важно сделать до выхода из didFinishLaunching: если приложение запустилось
        // из-за нажатия на пуш, iOS сразу после запуска передаст это нажатие делегату.
        configurePushNotifications(for: application)
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        clearBadge()
        presentPendingCallPreview()
    }

    /// `"badge": 1` из payload ставит цифру на иконку. Сама она не пропадает —
    /// её сбрасывает приложение, когда пользователь его открыл.
    private func clearBadge() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
}
