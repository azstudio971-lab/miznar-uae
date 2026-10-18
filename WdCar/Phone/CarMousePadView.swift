import SwiftUI

/// Phone-side touchpad for the WudCar entertainment browser.
struct CarMousePadView: View {
    @ObservedObject private var bridge = CarMouseBridge.shared
    @ObservedObject private var app = AppState.shared
    @ObservedObject private var driving = DrivingMonitor.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var lastPoint: CGPoint?
    @State private var moved = false

    private var padColor: Color {
        colorScheme == .dark
            ? Color(red: 0.22, green: 0.25, blue: 0.29)
            : Color(red: 0.82, green: 0.85, blue: 0.88)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Label(app.isCarConnected
                      ? tr("اتصلت السيارة — افتح الترفيه للتحكم بالمتصفح", "Car connected — open Entertainment to control its browser")
                      : tr("اتصل بالسيارة لاستخدام لوحة الماوس", "Connect CarPlay to use the mouse pad"),
                      systemImage: app.isCarConnected ? "car.side" : "car.side.lock")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text(tr("الماوس يعمل فقط داخل متصفح قسم الترفيه أثناء توقف السيارة.",
                        "Mouse works only in the Entertainment browser while the car is stopped."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("phone.mouse.safetyNote")

                HStack(spacing: 10) {
                    scrollButton("arrow.up", tr("تمرير للأعلى", "Scroll up"), dy: -0.65)
                    scrollButton("arrow.down", tr("تمرير للأسفل", "Scroll down"), dy: 0.65)
                }

                GeometryReader { geometry in
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(padColor.gradient)
                            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(.white.opacity(colorScheme == .dark ? 0.2 : 0.55), lineWidth: 1))
                            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
                        VStack(spacing: 12) {
                            Image(systemName: "cursorarrow.motionlines")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(colorScheme == .dark ? Color.white : Color.wdNavy)
                            Text(tr("لوحة اللمس", "Touchpad"))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(colorScheme == .dark ? Color.white : Color.primary)
                            Text(tr("حرّك إصبعك لتحريك المؤشر، وانقر للتحديد", "Move your finger to move the pointer; tap to select"))
                                .font(.caption)
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.76) : Color.secondary)
                        }
                        .allowsHitTesting(false)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            guard !driving.isMoving else { return }
                            if let lastPoint {
                                let dx = (value.location.x - lastPoint.x) / max(geometry.size.width, 1)
                                let dy = (value.location.y - lastPoint.y) / max(geometry.size.height, 1)
                                if abs(dx) + abs(dy) > 0.001 {
                                    moved = true
                                    bridge.send(.move(CGPoint(x: dx, y: dy)))
                                }
                            }
                            lastPoint = value.location
                        }
                        .onEnded { _ in
                            if !driving.isMoving, !moved { bridge.send(.click) }
                            lastPoint = nil
                            moved = false
                        })
                    .accessibilityIdentifier("phone.mouse.touchpad")
                }
                .frame(minHeight: 220, maxHeight: .infinity)
                .disabled(driving.isMoving)

                if driving.isMoving {
                    Label(tr("توقّف لاستخدام الماوس", "Stop the car to use the mouse"), systemImage: "pause.circle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .navigationTitle(tr("الماوس", "Mouse"))
            .onAppear { bridge.setActive(true) }
            .onDisappear { bridge.setActive(false) }
        }
        .environment(\.layoutDirection, L10n.language == .ar ? .rightToLeft : .leftToRight)
    }

    private func scrollButton(_ symbol: String, _ title: String, dy: CGFloat) -> some View {
        Button { if !driving.isMoving { bridge.send(.scroll(CGPoint(x: 0, y: dy))) } } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(colorScheme == .dark ? Color.white : Color.primary)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(colorScheme == .dark ? 0.15 : 0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(driving.isMoving)
        .accessibilityIdentifier(dy < 0 ? "phone.mouse.scroll.up" : "phone.mouse.scroll.down")
    }
}
