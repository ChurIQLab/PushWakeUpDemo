import UIKit

struct AppEvent: Codable {

    /// Тип события — по нему на главном экране выбираются иконка и цвет.
    enum Kind: String, Codable {
        case launch      // процесс приложения запущен
        case push        // пуш пришёл, пока приложение открыто
        case tap         // пользователь нажал на пуш
        case answer      // нажали кнопку «Ответить» в пуше
        case decline     // нажали кнопку «Отклонить» в пуше
        case dismiss     // пуш смахнули
        case screen      // показан экран
        case token       // получен APNs- или FCM-токен
        case permission  // ответ на запрос разрешения
        case warning     // что-то пришло не так, как ожидали
        case error       // ошибка
        case info
    }

    let date: Date
    let kind: Kind
    let title: String
    let details: String?
    /// Состояние приложения в момент события: «активно», «в фоне», «холодный старт»...
    let appState: String?

    init(date: Date, kind: Kind, title: String, details: String?, appState: String?) {
        self.date = date
        self.kind = kind
        self.title = title
        self.details = details
        self.appState = appState
    }

    /// Записи, сохранённые до появления `kind` и `appState`, тоже читаются.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .info
        title = try container.decode(String.self, forKey: .title)
        details = try container.decodeIfPresent(String.self, forKey: .details)
        appState = try container.decodeIfPresent(String.self, forKey: .appState)
    }
}

/// Журнал событий. Хранится в UserDefaults, чтобы после холодного старта
/// (приложение было убито, нажали на пуш) было видно, что произошло.
enum EventLog {
    static let didChangeNotification = Notification.Name("EventLogDidChange")

    private static let key = "event_log"
    private static let limit = 200
    private static let launchDate = Date()

    /// Добавляет событие с текущим состоянием приложения. Вызывать на главном потоке.
    static func add(_ kind: AppEvent.Kind, _ title: String, details: String? = nil) {
        let event = AppEvent(date: Date(), kind: kind, title: title, details: details, appState: appStateDescription)
        print("📝 \(title) [\(event.appState ?? "")]\(details.map { " — \($0)" } ?? "")")

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
        return "\(state) · холодный старт \(String(format: "%.1f", uptime)) с"
    }
}
