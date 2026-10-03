import UserNotifications

/// Кнопки пуша звонка.
///
/// Сервер в `aps` присылает `"category": "CALL_NOTIFICATION"`. Сами кнопки в payload не передаются —
/// приложение заранее сообщает iOS, какие кнопки есть у этой категории. Тогда при долгом нажатии
/// на пуш (или при развороте на экране блокировки) iOS покажет их, не запуская приложение.
enum CallNotificationCategory {

    static let identifier = "CALL_NOTIFICATION"

    enum Action {
        static let answer = "CALL_ANSWER"
        static let decline = "CALL_DECLINE"
    }

    /// Вызывать при каждом запуске, до выхода из `didFinishLaunching`.
    static func register() {
        // .foreground — iOS откроет приложение (и разблокирует телефон).
        let answer = UNNotificationAction(identifier: Action.answer,
                                          title: "Ответить",
                                          options: [.foreground],
                                          icon: UNNotificationActionIcon(systemImageName: "phone.fill"))

        // Без .foreground — iOS разбудит приложение в фоне, экран не откроется.
        // .destructive — кнопка красная.
        let decline = UNNotificationAction(identifier: Action.decline,
                                           title: "Отклонить",
                                           options: [.destructive],
                                           icon: UNNotificationActionIcon(systemImageName: "phone.down.fill"))

        // .customDismissAction — iOS сообщит приложению, что пуш смахнули («Очистить»).
        // Без этой опции смахивание проходит молча.
        let category = UNNotificationCategory(identifier: identifier,
                                              actions: [answer, decline],
                                              intentIdentifiers: [],
                                              hiddenPreviewsBodyPlaceholder: "Входящий звонок",
                                              options: [.customDismissAction])

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
