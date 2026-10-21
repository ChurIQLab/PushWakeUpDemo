import UIKit

/// Состояние приложения для журнала — только в приложении (у расширения нет UIApplication).
extension EventLog {

    private static var launchDate = Date()

    /// Вызвать в начале didFinishLaunching: отсчёт «холодного старта» идёт от запуска процесса.
    static func markLaunch() {
        launchDate = Date()
        stateProvider = { appStateDescription }
    }

    private static var appStateDescription: String {
        let state: String
        switch UIApplication.shared.applicationState {
        case .active: state = "активно"
        case .inactive: state = "неактивно"
        case .background: state = "в фоне"
        @unknown default: state = "неизвестно"
        }
        let uptime = Date().timeIntervalSince(launchDate)
        guard uptime < 3 else { return state }
        return "\(state) · холодный старт \(String(format: "%.1f", uptime)) с"
    }
}
