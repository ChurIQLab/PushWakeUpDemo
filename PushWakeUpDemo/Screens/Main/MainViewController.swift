import UIKit

/// Главный экран: FCM-токен (для отправки тестового пуша) и журнал событий —
/// что пришло, когда и в каком состоянии было приложение.
final class MainViewController: UITableViewController {

    private enum Section: Int, CaseIterable {
        case token
        case log
    }

    private var events: [AppEvent] = []

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
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
        title = "Push WakeUp Demo"
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .trash, primaryAction: UIAction { [weak self] _ in
            self?.confirmClearLog()
        })

        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: EventLog.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: FCMTokenStore.didChangeNotification, object: nil)
        reload()
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

    @objc private func reload() {
        DispatchQueue.main.async {
            self.events = EventLog.all()
            self.tableView.reloadData()
        }
    }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .token: return 1
        case .log: return max(events.count, 1)
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .token: return "FCM-токен (нажмите, чтобы скопировать)"
        case .log: return "Журнал событий"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = UIListContentConfiguration.subtitleCell()
        content.secondaryTextProperties.color = .secondaryLabel

        switch Section(rawValue: indexPath.section)! {
        case .token:
            content.text = FCMTokenStore.current ?? "Ещё не получен"
            content.textProperties.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            content.textProperties.numberOfLines = 3

        case .log:
            cell.selectionStyle = .none
            if events.isEmpty {
                content.text = "Пока пусто"
            } else {
                let event = events[indexPath.row]
                content.text = "\(timeFormatter.string(from: event.date))  \(event.title)"
                content.secondaryText = event.details
            }
        }

        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .token, let token = FCMTokenStore.current else { return }
        UIPasteboard.general.string = token
        let alert = UIAlertController(title: "Скопировано", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
