import UIKit

/// Экран предпросмотра звонка: сюда попадаем по нажатию на пуш.
/// Пока только показывает, что пришло в payload. Сам звонок — на следующих этапах.
final class CallPreviewViewController: UITableViewController {

    /// Как открыли экран — показываем в подписи, чтобы было видно разницу.
    enum Origin {
        case tap     // обычное нажатие на пуш
        case answer  // кнопка «Ответить» в пуше

        var subtitle: String {
            switch self {
            case .tap: return "Приложение открыто нажатием на пуш"
            case .answer: return "Приложение открыто кнопкой «Ответить» в пуше"
            }
        }
    }

    private let callData: PushNotificationData
    private let origin: Origin
    private let rows: [(title: String, value: String)]
    private var didLogAppearance = false

    init(callData: PushNotificationData, origin: Origin) {
        self.callData = callData
        self.origin = origin
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
        title = "Звонок"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        tableView.tableHeaderView = makeHeader()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Высота шапки таблицы не считается сама — подгоняем под содержимое.
        guard let header = tableView.tableHeaderView else { return }
        let height = header.systemLayoutSizeFitting(CGSize(width: tableView.bounds.width, height: 0),
                                                    withHorizontalFittingPriority: .required,
                                                    verticalFittingPriority: .fittingSizeLevel).height
        if header.frame.height != height {
            header.frame.size.height = height
            tableView.tableHeaderView = header
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // viewDidAppear приходит снова, если экран начали смахивать и отпустили.
        guard !didLogAppearance else { return }
        didLogAppearance = true
        EventLog.add(.screen, "Экран предпросмотра показан", details: "Домофон: \(callData.addr)")
    }

    // MARK: - Header

    /// Иконка, адрес домофона и подпись — чтобы сразу было видно, какой это звонок.
    private func makeHeader() -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "bell.fill",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 34, weight: .semibold)))
        icon.tintColor = .white
        icon.contentMode = .center
        icon.backgroundColor = UIColor(named: "AccentColor") ?? .systemIndigo
        icon.layer.cornerRadius = 40
        icon.clipsToBounds = true
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 80),
            icon.heightAnchor.constraint(equalToConstant: 80)
        ])

        let titleLabel = UILabel()
        titleLabel.text = callData.addr.isEmpty ? "Домофон" : "Домофон: \(callData.addr)"
        titleLabel.font = .preferredFont(forTextStyle: .title2).withWeight(.bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = origin.subtitle
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.setCustomSpacing(16, after: icon)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let header = UIView()
        header.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: header.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: header.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: header.layoutMarginsGuide.trailingAnchor)
        ])
        return header
    }

    // MARK: - Table

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
        content.textProperties.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        content.secondaryText = rows[indexPath.row].value.isEmpty ? "—" : rows[indexPath.row].value
        content.prefersSideBySideTextAndSecondaryText = true
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        return cell
    }
}

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        return UIFont(descriptor: descriptor, size: 0)
    }
}
