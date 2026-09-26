import UIKit

/// Экран предпросмотра звонка: сюда попадаем по тапу на пуш.
/// Пока только показывает, что пришло в payload. Сам звонок — на следующих этапах.
final class CallPreviewViewController: UITableViewController {

    private let rows: [(title: String, value: String)]

    init(callData: PushNotificationData) {
        rows = [
            ("addr", callData.addr),
            ("call_id", callData.callID),
            ("type", callData.type),
            ("service_url", callData.serviceURL),
            ("panele_id", callData.paneleID),
            ("asterisk_url", callData.asteriskURL),
            ("rtsp", callData.rtsp),
            ("token", callData.token)
        ]
        super.init(style: .insetGrouped)
        title = callData.addr.isEmpty ? "Домофон" : "Домофон: \(callData.addr)"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        EventLog.add("Экран предпросмотра показан", details: title)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Payload из пуша"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = UIListContentConfiguration.valueCell()
        content.text = rows[indexPath.row].title
        content.secondaryText = rows[indexPath.row].value.isEmpty ? "—" : rows[indexPath.row].value
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        return cell
    }
}
