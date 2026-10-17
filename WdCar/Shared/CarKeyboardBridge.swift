import Foundation
import Combine

/// يربط شاشة الكتابة في السيارة بلوحة مفاتيح الهاتف ("لوحة مفاتيح CarPlay" في CarTV).
/// أي حرف يُكتب في الهاتف يظهر فوراً في السيارة، والعكس.
final class CarKeyboardBridge: ObservableObject {
    static let shared = CarKeyboardBridge()

    enum Source { case car, phone }

    @Published var isPhoneEditorPresented = false
    @Published private(set) var text = ""
    @Published private(set) var placeholder = ""
    @Published private(set) var isActive = false

    let textChanges = PassthroughSubject<(String, Source), Never>()
    let submits = PassthroughSubject<Void, Never>()
    let cancels = PassthroughSubject<Void, Never>()

    /// السيارة فتحت شاشة الكتابة: نفتح لوحة الهاتف تلقائياً
    func begin(initial: String, placeholder: String) {
        text = initial
        self.placeholder = placeholder
        isActive = true
        isPhoneEditorPresented = true
    }

    func setText(_ newText: String, from source: Source) {
        guard newText != text else { return }
        text = newText
        textChanges.send((newText, source))
    }

    func submit() {
        guard isActive else { return }
        submits.send(())
        end()
    }

    func cancel() {
        guard isActive else { return }
        cancels.send(())
        end()
    }

    private func end() {
        isActive = false
        isPhoneEditorPresented = false
    }
}
