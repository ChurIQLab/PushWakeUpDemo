import UIKit

/// VoIP-пуш → CallKit → «Ответить» → экран предпросмотра.
///
/// В отличие от обычного пуша, VoIP-пуш будит приложение сам: iOS запускает процесс
/// (даже убитый) и вызывает PushKit, а приложение тут же показывает звонок через CallKit.
extension AppDelegate {

    /// Вызывать в `didFinishLaunching` при каждом запуске.
    func configureVoIP() {
        callKitService.onAnswer = { [weak self] callData in
            self?.showCallPreview(with: callData, origin: .callKit)
        }
        voipPushService.onIncomingCall = { [weak self] callData, completion in
            guard let self else {
                completion()
                return
            }
            self.callKitService.reportIncomingCall(callData, completion: completion)
        }
        voipPushService.start()
    }
}
