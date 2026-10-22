import CallKit
import UIKit

/// CallKit — нативный экран звонка iOS, как у обычного телефонного звонка.
///
/// Показывается поверх всего, в том числе на заблокированном экране. Для VoIP-пуша
/// он обязателен: каждый VoIP-пуш нужно сразу зарепортить через `reportNewIncomingCall`.
/// Сам звонок (SIP, видео) здесь не делаем: после «Ответить» открываем экран предпросмотра.
final class CallKitService: NSObject {

    /// Нажали «Ответить» на экране CallKit.
    var onAnswer: ((PushNotificationData) -> Void)?

    /// Через сколько секунд без ответа звонок считается пропущенным.
    private static let ringTimeout: TimeInterval = 30

    private let provider: CXProvider
    private let callController = CXCallController()
    /// Активные звонки: UUID звонка в CallKit → данные из пуша.
    private var calls: [UUID: PushNotificationData] = [:]
    private var answeredCalls: Set<UUID> = []

    override init() {
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = true
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]
        configuration.includesCallsInRecents = false
        // Рингтон ищется в бандле приложения (Resources/Sounds)
        configuration.ringtoneSound = "customSound.wav"

        provider = CXProvider(configuration: configuration)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    /// Показать входящий звонок. `completion` вызывается после ответа CallKit —
    /// его передаём в PushKit, когда звонок уже зарепорчен.
    func reportIncomingCall(_ callData: PushNotificationData, completion: @escaping () -> Void) {
        let uuid = UUID()
        let name = callData.addr.isEmpty ? "Домофон" : "Домофон: \(callData.addr)"

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: name)
        update.localizedCallerName = name
        update.hasVideo = true   // видеозвонок: после «Ответить» iOS сразу открывает приложение
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false

        provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    // Например, включён «Не беспокоить» с блокировкой звонков
                    EventLog.add(.error, "CallKit не показал звонок", details: error.localizedDescription)
                } else {
                    self?.calls[uuid] = callData
                    EventLog.add(.callKit, "Показан экран звонка CallKit", details: name)
                    self?.endIfUnanswered(uuid)
                }
                completion()
            }
        }
    }

    /// Завершить звонок из приложения (закрыли экран предпросмотра).
    func endCall(callID: String) {
        guard let uuid = calls.first(where: { $0.value.callID == callID })?.key else { return }
        callController.request(CXTransaction(action: CXEndCallAction(call: uuid))) { error in
            if let error {
                DispatchQueue.main.async {
                    EventLog.add(.error, "Не удалось завершить звонок в CallKit", details: error.localizedDescription)
                }
            }
        }
    }

    private func endIfUnanswered(_ uuid: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.ringTimeout) { [weak self] in
            guard let self, let callData = self.calls[uuid], !self.answeredCalls.contains(uuid) else { return }
            self.provider.reportCall(with: uuid, endedAt: Date(), reason: .unanswered)
            self.calls[uuid] = nil
            EventLog.add(.warning, "Звонок пропущен",
                         details: "Никто не ответил за \(Int(Self.ringTimeout)) с. Домофон: \(callData.addr)")
        }
    }
}

// MARK: - CXProviderDelegate

extension CallKitService: CXProviderDelegate {

    func providerDidReset(_ provider: CXProvider) {
        calls.removeAll()
        answeredCalls.removeAll()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        guard let callData = calls[action.callUUID] else {
            action.fail()
            return
        }
        answeredCalls.insert(action.callUUID)
        EventLog.add(.answer, "Ответили в CallKit", details: "Открываем предпросмотр. Домофон: \(callData.addr)")
        // Здесь реальное приложение подключается к SIP и только потом вызывает fulfill.
        action.fulfill()
        onAnswer?(callData)
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        let callData = calls[action.callUUID]
        if answeredCalls.contains(action.callUUID) {
            EventLog.add(.info, "Звонок завершён", details: callData.map { "Домофон: \($0.addr)" })
        } else {
            // Завершение до ответа: нажали «Отклонить» или звонок сбросила система —
            // CallKit их не различает. Здесь реальное приложение сообщает серверу, что звонок отклонён.
            EventLog.add(.decline, "Звонок отклонён в CallKit",
                         details: "Нажали «Отклонить» или звонок сбросила система" + (callData.map { ". Домофон: \($0.addr)" } ?? ""))
        }
        calls[action.callUUID] = nil
        answeredCalls.remove(action.callUUID)
        action.fulfill()
    }
}
