import UIKit

final class IncomingCallViewController: UIViewController {

    private var callData: PushNotificationData?

    private lazy var label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.text = "Incoming Call"
        return label
    }()

    private lazy var acceptButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Accept", for: .normal)
        button.addTarget(self, action: #selector(acceptCall), for: .touchUpInside)
        return button
    }()

    private lazy var declineButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Decline", for: .normal)
        button.addTarget(self, action: #selector(declineCall), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .white
        view.addSubview(label)
        view.addSubview(acceptButton)
        view.addSubview(declineButton)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            acceptButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 50),
            acceptButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 50),
            acceptButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -50),
            acceptButton.heightAnchor.constraint(equalToConstant: 50),

            declineButton.topAnchor.constraint(equalTo: acceptButton.bottomAnchor, constant: 20),
            declineButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 50),
            declineButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -50),
            declineButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    @objc
    private func acceptCall() {
        let alert = UIAlertController(title: "Call Accepted", message: "Simulating video streaming", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    @objc
    private func declineCall() {
        dismiss(animated: true, completion: nil)
    }

    func setup(with callData: PushNotificationData) {
        self.callData = callData
    }
}
