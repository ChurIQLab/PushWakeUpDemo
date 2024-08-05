import Foundation

final class SIPService {

    private var callData: PushNotificationData

    init(callData: PushNotificationData) {
        self.callData = callData
    }

    func startService(completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            completion()
        }
    }
}
