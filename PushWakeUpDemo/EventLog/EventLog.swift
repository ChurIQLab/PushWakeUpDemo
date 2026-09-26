import UIKit

struct AppEvent: Codable {
    let date: Date
    let title: String
    let details: String
}

/// Журнал событий. Хранится в UserDefaults, чтобы после холодного старта
/// (приложение было убито, тапнули пуш) было видно, что произошло.
enum EventLog {
    static let didChangeNotification = Notification.Name("EventLogDidChange")

    private static let key = "event_log"
    private static let limit = 100
    private static let launchDate = Date()

    /// Добавляет событие с текущим состоянием приложения. Вызывать на главном потоке.
    static func add(_ title: String, details: String? = nil) {
        let state = "Состояние: \(appStateDescription)"
        let event = AppEvent(date: Date(), title: title, details: [state, details].compactMap { $0 }.joined(separator: "\n"))
        print("📝 \(event.title) — \(event.details)")

        var events = all()
        events.insert(event, at: 0)
        save(Array(events.prefix(limit)))
    }

    static func all() -> [AppEvent] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([AppEvent].self, from: data)) ?? []
    }

    static func clear() {
        save([])
    }

    /// Вызвать в начале didFinishLaunching, чтобы отсчёт «холодного старта» шёл от запуска.
    static func markLaunch() {
        _ = launchDate
    }

    private static func save(_ events: [AppEvent]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(events), forKey: key)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
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
        return "\(state), холодный старт (процесс запущен \(String(format: "%.1f", uptime)) с назад)"
    }
}
