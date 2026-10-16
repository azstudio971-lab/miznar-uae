import SwiftUI

/// tr("لوحة مفاتيح CarPlay", "CarPlay Keyboard"): تظهر على الهاتف تلقائياً عندما تضغط على حقل كتابة في السيارة.
/// كل حرف يُكتب هنا يظهر في السيارة مباشرة.
struct PhoneCarKeyboardSheet: View {
    @ObservedObject private var bridge = CarKeyboardBridge.shared
    @FocusState private var focused: Bool

    private var textBinding: Binding<String> {
        Binding(get: { bridge.text }, set: { bridge.setText($0, from: .phone) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "car.fill")
                    .font(.title2)
                    .foregroundStyle(Color.wdAccent)
                Text(tr("لوحة مفاتيح CarPlay", "CarPlay Keyboard"))
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    bridge.isPhoneEditorPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.gray)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color(white: 0.2)))
                }
            }

            TextField(bridge.placeholder.isEmpty ? tr("اكتب هنا", "Type here") : bridge.placeholder, text: textBinding)
                .focused($focused)
                .font(.title3)
                .foregroundStyle(.white)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { bridge.submit() }
                .padding(.horizontal, 18)
                .frame(height: 64)
                .background(RoundedRectangle(cornerRadius: 22).fill(Color(white: 0.17)))

            Label(bridge.isActive ? tr("متزامن مع CarPlay", "Synced with CarPlay") : tr("لا يوجد حقل كتابة مفتوح في السيارة", "No text field is open in the car"),
                  systemImage: bridge.isActive ? "arrow.triangle.2.circlepath" : "exclamationmark.circle")
                .font(.subheadline)
                .foregroundStyle(.gray)

            if bridge.isActive {
                HStack(spacing: 12) {
                    Button {
                        bridge.submit()
                    } label: {
                        Label(tr("بحث", "Search"), systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.wdAccent)
                    .controlSize(.large)

                    Button(role: .cancel) {
                        bridge.cancel()
                    } label: {
                        Text(tr("إلغاء", "Cancel")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }

            Spacer()
        }
        .padding(20)
        .background(Color(white: 0.11).ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
        }
    }
}
