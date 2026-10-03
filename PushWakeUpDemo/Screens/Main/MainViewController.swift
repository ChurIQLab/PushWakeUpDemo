import UIKit

/// Главный экран: FCM-токен (для отправки тестового пуша) и журнал событий,
/// сгруппированный по дням, — что пришло, когда и в каком состоянии было приложение.
final class MainViewController: UITableViewController {

    /// Секция журнала за один день.
    private struct Day {
        let date: Date
        let events: [AppEvent]
    }

    private var days: [Day] = []

    /// Секция 0 — токен, дальше — дни журнала.
    private let tokenSection = 0

    private static let russian = Locale(identifier: "ru_RU")

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = russian
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = russian
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        return formatter
    }()

    private let dayWithYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = russian
        formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        return formatter
    }()

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Push WakeUp"
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .trash, primaryAction: UIAction { [weak self] _ in
            self?.confirmClearLog()
        })

        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: EventLog.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: FCMTokenStore.didChangeNotification, object: nil)
        reload()
    }

    @objc private func reload() {
        DispatchQueue.main.async {
            let calendar = Calendar.current
            let grouped = Dictionary(grouping: EventLog.all()) { calendar.startOfDay(for: $0.date) }
            self.days = grouped
                .map { Day(date: $0.key, events: $0.value.sorted { $0.date > $1.date }) }
                .sorted { $0.date > $1.date }
            self.tableView.reloadData()
        }
    }

    /// Кнопка стоит там же, где крестик у экрана предпросмотра, — без подтверждения
    /// лишний тап после закрытия предпросмотра стирал журнал.
    private func confirmClearLog() {
        let alert = UIAlertController(title: "Очистить журнал?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Очистить", style: .destructive) { _ in
            EventLog.clear()
        })
        present(alert, animated: true)
    }

    private func title(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Сегодня" }
        if calendar.isDateInYesterday(day) { return "Вчера" }
        if calendar.isDate(day, equalTo: Date(), toGranularity: .year) {
            return dayFormatter.string(from: day)
        }
        return dayWithYearFormatter.string(from: day)
    }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int {
        // Пустой журнал — одна секция с подсказкой.
        1 + max(days.count, 1)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section != tokenSection, !days.isEmpty else { return 1 }
        return days[section - 1].events.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == tokenSection { return "FCM-токен" }
        if days.isEmpty { return "Журнал" }
        return title(for: days[section - 1].date)
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == tokenSection else { return nil }
        return "Нажмите, чтобы скопировать или отправить AirDrop. Токен также печатается в консоль Xcode: FCM_TOKEN=…"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == tokenSection {
            return tokenCell()
        }
        if days.isEmpty {
            return emptyLogCell()
        }
        return eventCell(days[indexPath.section - 1].events[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == tokenSection, let token = FCMTokenStore.current else { return }

        // Токен нужен на Mac (консоль Firebase или Scripts/send_fcm_push.sh):
        // в системном меню есть «Скопировать» и AirDrop.
        let share = UIActivityViewController(activityItems: [token], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
        present(share, animated: true)
    }

    // MARK: - Cells

    private func tokenCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = UIListContentConfiguration.cell()
        content.image = AppEvent.Kind.token.badgeImage
        if let token = FCMTokenStore.current {
            content.text = token
            content.textProperties.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            cell.accessoryView = UIImageView(image: UIImage(systemName: "square.and.arrow.up"))
        } else {
            content.text = "Ещё не получен"
            content.textProperties.color = .secondaryLabel
            cell.selectionStyle = .none
        }
        cell.contentConfiguration = content
        return cell
    }

    private func emptyLogCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = UIListContentConfiguration.subtitleCell()
        content.image = AppEvent.Kind.info.badgeImage
        content.text = "Пока пусто"
        content.secondaryText = "Отправьте пуш: ./Scripts/send_fcm_push.sh <токен>, а на симуляторе — xcrun simctl push"
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        return cell
    }

    private func eventCell(_ event: AppEvent) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none

        var content = UIListContentConfiguration.subtitleCell()
        content.image = event.kind.badgeImage
        content.text = event.title
        content.textProperties.font = .preferredFont(forTextStyle: .subheadline).bold()
        content.textToSecondaryTextVerticalPadding = 4
        content.secondaryAttributedText = secondaryText(for: event)
        cell.contentConfiguration = content

        let time = UILabel()
        time.text = timeFormatter.string(from: event.date)
        time.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        time.textColor = .tertiaryLabel
        time.sizeToFit()
        cell.accessoryView = time
        return cell
    }

    /// Детали обычным цветом, состояние приложения — мелко и цветом события.
    private func secondaryText(for event: AppEvent) -> NSAttributedString {
        let text = NSMutableAttributedString()
        if let details = event.details, !details.isEmpty {
            text.append(NSAttributedString(string: details, attributes: [
                .font: UIFont.preferredFont(forTextStyle: .footnote),
                .foregroundColor: UIColor.secondaryLabel
            ]))
        }
        if let state = event.appState {
            if text.length > 0 { text.append(NSAttributedString(string: "\n")) }
            text.append(NSAttributedString(string: state, attributes: [
                .font: UIFont.preferredFont(forTextStyle: .caption1),
                .foregroundColor: event.kind.color
            ]))
        }
        return text
    }
}

private extension UIFont {
    func bold() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
