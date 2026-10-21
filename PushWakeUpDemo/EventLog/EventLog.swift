import Foundation

struct AppEvent: Codable {

    /// Тип события — по нему на главном экране выбираются иконка и цвет.
    enum Kind: String, Codable {
        case launch      // процесс приложения запущен
        case push        // пуш пришёл, пока приложение открыто
        case tap         // пользователь нажал на пуш
        case answer      // нажали кнопку «Ответить» в пуше
        case decline     // нажали кнопку «Отклонить» в пуше
        case dismiss     // пуш смахнули
        case serviceExtension // Notification Service Extension изменил пуш
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

/// Журнал событий. Общий для приложения и Notification Service Extension:
/// расширение — отдельный процесс, поэтому журнал лежит в App Group, а не в UserDefaults приложения.
/// Хранится между запусками, чтобы после холодного старта было видно, что произошло.
enum EventLog {
    static let didChangeNotification = Notification.Name("EventLogDidChange")

    /// Должен совпадать с App Group в entitlements приложения и расширения.
    static let appGroup = "group.com.churiqlab.PushWakeUpDemo"

    /// Кто пишет в журнал и в каком он состоянии. Приложение подставляет
    /// «активно / в фоне / холодный старт», расширение — своё описание.
    static var stateProvider: () -> String? = { nil }

    private static let key = "event_log"
    private static let limit = 200
    private static let storage = UserDefaults(suiteName: appGroup) ?? .standard

    /// Добавляет событие. В приложении вызывать на главном потоке.
    static func add(_ kind: AppEvent.Kind, _ title: String, details: String? = nil) {
        let event = AppEvent(date: Date(), kind: kind, title: title, details: details, appState: stateProvider())
        print("📝 \(title) [\(event.appState ?? "")]\(details.map { " — \($0)" } ?? "")")

        var events = all()
        events.insert(event, at: 0)
        save(Array(events.prefix(limit)))
    }

    static func all() -> [AppEvent] {
        migrateFromStandardDefaultsIfNeeded()
        guard let data = storage.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([AppEvent].self, from: data)) ?? []
    }

    static func clear() {
        save([])
    }

    private static func save(_ events: [AppEvent]) {
        storage.set(try? JSONEncoder().encode(events), forKey: key)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    /// До этапа 3 журнал лежал в UserDefaults приложения — переносим его один раз.
    private static func migrateFromStandardDefaultsIfNeeded() {
        guard storage !== UserDefaults.standard,
              let old = UserDefaults.standard.data(forKey: key) else { return }
        if storage.data(forKey: key) == nil {
            storage.set(old, forKey: key)
        }
        UserDefaults.standard.removeObject(forKey: key)
    }
}
