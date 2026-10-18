import Combine
import CoreGraphics

/// In-app remote pointer for WudCar's own external-display browser.
/// It does not synthesize input for CarPlay's native templates or other apps.
final class CarMouseBridge: ObservableObject {
    static let shared = CarMouseBridge()

    enum NavigationCommand { case back, forward, home, reload }
    enum Input {
        case move(CGPoint)       // normalized to the touchpad size
        case scroll(CGPoint)     // normalized to the touchpad size
        case click
        case navigate(NavigationCommand)
    }

    @Published private(set) var isActive = false
    @Published private(set) var input: Input?

    private init() {}

    func setActive(_ active: Bool) { isActive = active }
    func send(_ input: Input) { self.input = input }
}
