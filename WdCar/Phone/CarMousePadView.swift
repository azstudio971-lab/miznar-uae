import SwiftUI

/// Phone-side controls for the WudCar browser shown in its external-display scene.
struct CarMousePadView: View {
    @ObservedObject private var bridge = CarMouseBridge.shared
    @ObservedObject private var app = AppState.shared
    @State private var lastPoint: CGPoint?
    @State private var moved = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Label(app.carScreenActive
                      ? tr("لوحة التحكم بمتصفح وُد كار على شاشة السيارة", "Control WudCar's browser on the car display")
                      : tr("اتصل بشاشة السيارة لاستخدام لوحة التحكم", "Connect the car display to use these controls"),
                      systemImage: app.carScreenActive ? "car.side" : "car.side.lock")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                GeometryReader { geometry in
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.wdNavy.opacity(0.96))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.wdAccent.opacity(0.75), lineWidth: 1.5))
                        VStack(spacing: 8) {
                            Image(systemName: "cursorarrow.motionlines")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(Color.wdAccent)
                            Text(tr("لوحة لمس", "Touchpad"))
                                .font(.headline)
                            Text(tr("حرّك إصبعك للمؤشر، وانقر للفتح", "Move to point, tap to open"))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.76))
                        }
                        .allowsHitTesting(false)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 24))
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
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
                            if !moved { bridge.send(.click) }
                            lastPoint = nil
                            moved = false
                        })
                    .accessibilityIdentifier("phone.mouse.touchpad")
                }
                .frame(minHeight: 170, maxHeight: 230)

                HStack(spacing: 10) {
                    commandButton("chevron.backward", tr("رجوع", "Back"), .back)
                    commandButton("chevron.forward", tr("تقدم", "Forward"), .forward)
                    commandButton("house", tr("الرئيسية", "Home"), .home)
                    commandButton("arrow.clockwise", tr("تحديث", "Reload"), .reload)
                }

                HStack(spacing: 14) {
                    directionButton("chevron.left", dx: -0.035, dy: 0)
                    VStack(spacing: 8) {
                        directionButton("chevron.up", dx: 0, dy: -0.04)
                        HStack(spacing: 8) {
                            directionButton("chevron.down", dx: 0, dy: 0.04)
                            Button { bridge.send(.click) } label: {
                                Label(tr("نقر", "Click"), systemImage: "hand.tap")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(minWidth: 84, minHeight: 42)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.wdAccent)
                            .accessibilityIdentifier("phone.mouse.click")
                        }
                    }
                    directionButton("chevron.right", dx: 0.035, dy: 0)
                }

                HStack(spacing: 12) {
                    scrollButton("arrow.up", tr("تمرير لأعلى", "Scroll up"), dy: -0.65)
                    scrollButton("arrow.down", tr("تمرير لأسفل", "Scroll down"), dy: 0.65)
                }

                Text(tr("يعمل المؤشر داخل متصفح وُد كار فقط. بعض المواقع تمنع النقر البرمجي، وقد لا يستجيب تشغيل الفيديو أو النوافذ المنبثقة.",
                        "The pointer works only inside WudCar's browser. Some sites block scripted clicks, so video playback and pop-ups may not respond."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle(tr("الماوس", "Mouse"))
            .onAppear { bridge.setActive(true) }
            .onDisappear { bridge.setActive(false) }
        }
        .environment(\.layoutDirection, L10n.language == .ar ? .rightToLeft : .leftToRight)
    }

    private func commandButton(_ symbol: String, _ title: String, _ command: CarMouseBridge.NavigationCommand) -> some View {
        Button { bridge.send(.navigate(command)) } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)
    }

    private func directionButton(_ symbol: String, dx: CGFloat, dy: CGFloat) -> some View {
        Button {
            bridge.send(.move(CGPoint(x: dx, y: dy)))
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(tr("تحريك المؤشر", "Move pointer"))
    }

    private func scrollButton(_ symbol: String, _ title: String, dy: CGFloat) -> some View {
        Button { bridge.send(.scroll(CGPoint(x: 0, y: dy))) } label: {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(.bordered)
    }
}
