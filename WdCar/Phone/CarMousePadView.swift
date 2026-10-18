import SwiftUI

/// Phone-side remote for WudCar's own CarPlay display and browser.
struct CarMousePadView: View {
    @ObservedObject private var bridge = CarMouseBridge.shared
    @ObservedObject private var app = AppState.shared
    @ObservedObject private var playback = PlaybackManager.shared
    @State private var lastPoint: CGPoint?
    @State private var moved = false
    @State private var showTVPicker = false

    private let silver = Color(red: 0.22, green: 0.24, blue: 0.27)

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Label(app.carScreenActive
                      ? tr("شاشة السيارة متصلة — تحكم بوُد كار من هنا", "Car display connected — control WudCar here")
                      : (app.isCarConnected ? tr("CarPlay متصل — اختر قنواتك من الهاتف", "CarPlay connected — choose channels from iPhone")
                                             : tr("اتصل بالسيارة لاستخدام لوحة التحكم", "Connect CarPlay to use these controls")),
                      systemImage: app.isCarConnected ? "car.side" : "car.side.lock")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    sectionButton("house.fill", tr("الرئيسية", "Home"), .home)
                    sectionButton("play.tv.fill", tr("الترفيه", "Entertainment"), .entertainment)
                    sectionButton("tv.fill", tr("التلفزيون", "TV"), .television)
                    sectionButton("gearshape.fill", tr("الإعدادات", "Settings"), .settings)
                }

                HStack(spacing: 8) {
                    actionButton("minus.magnifyingglass", tr("تصغير", "Zoom out")) { bridge.send(.zoom(-0.05)) }
                    actionButton("plus.magnifyingglass", tr("تكبير", "Zoom in")) { bridge.send(.zoom(0.05)) }
                    actionButton("arrow.up.left.and.arrow.down.right", tr("ملء الشاشة", "Fullscreen")) { bridge.send(.toggleVideoFullscreen) }
                    actionButton("gobackward.10", tr("10 ث للخلف", "Back 10s")) { bridge.send(.seek(-10)) }
                    actionButton("goforward.10", tr("10 ث للأمام", "Forward 10s")) { bridge.send(.seek(10)) }
                    actionButton("playpause.fill", tr("تشغيل/إيقاف", "Play/Pause")) { bridge.send(.playPause) }
                    actionButton("stop.fill", tr("إيقاف القناة", "Stop channel")) { bridge.send(.stopPlayback); playback.stop() }
                }

                Button { showTVPicker = true } label: {
                    Label(tr("اختيار قناة من الهاتف وتشغيلها على شاشة السيارة", "Choose a channel on iPhone and play it on the car display"), systemImage: "tv.and.mediabox")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(GlassRemoteButton())
                .disabled(!app.isCarConnected || app.carVideoSupport == .unsupported)

                HStack(spacing: 8) {
                    commandButton("chevron.backward", tr("رجوع", "Back"), .back)
                    commandButton("chevron.forward", tr("تقدم", "Forward"), .forward)
                    commandButton("house", tr("صفحة المتصفح", "Browser home"), .home)
                    commandButton("arrow.clockwise", tr("تحديث", "Reload"), .reload)
                }

                HStack(spacing: 8) {
                    scrollButton("arrow.up", tr("تمرير لأعلى", "Scroll up"), dy: -0.65)
                    scrollButton("arrow.down", tr("تمرير لأسفل", "Scroll down"), dy: 0.65)
                }

                HStack(spacing: 9) {
                    directionButton("chevron.left", dx: -0.035, dy: 0)
                    VStack(spacing: 7) {
                        directionButton("chevron.up", dx: 0, dy: -0.04)
                        Button { bridge.send(.click) } label: {
                            Label(tr("تحديد", "Select"), systemImage: "hand.tap")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 100, height: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.wdAccent)
                        .accessibilityIdentifier("phone.mouse.click")
                        directionButton("chevron.down", dx: 0, dy: 0.04)
                    }
                    directionButton("chevron.right", dx: 0.035, dy: 0)
                }

                Text(tr("يعمل التحكم داخل متصفح وُد كار وقسم التلفزيون فقط. بعض المواقع تمنع النقر البرمجي، وقد لا تستجيب بعض أزرار الفيديو.",
                        "Controls work inside WudCar's browser and TV section. Some sites block scripted clicks and video controls."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)

                GeometryReader { geometry in
                    ZStack {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(silver.gradient)
                            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.22), lineWidth: 1))
                            .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
                        VStack(spacing: 9) {
                            Image(systemName: "cursorarrow.motionlines")
                                .font(.system(size: 27, weight: .medium))
                                .foregroundStyle(Color.wdAccent)
                            Text(tr("لوحة اللمس", "Touchpad"))
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(tr("حرّك إصبعك للمؤشر، وانقر للتحديد", "Move to point, tap to select"))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.78))
                        }
                        .allowsHitTesting(false)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
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
                .frame(minHeight: 165, maxHeight: 205)


            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .navigationTitle(tr("الماوس", "Mouse"))
            .onAppear { bridge.setActive(true) }
            .onDisappear { bridge.setActive(false) }
            .sheet(isPresented: $showTVPicker) {
                NavigationStack {
                    XtreamHomeView(readOnly: true, presentPlaybackOnPhone: false)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(tr("إغلاق", "Close")) { showTVPicker = false }
                            }
                        }
                }
            }
        }
        .environment(\.layoutDirection, L10n.language == .ar ? .rightToLeft : .leftToRight)
    }

    private func sectionButton(_ symbol: String, _ title: String, _ section: CarMouseBridge.DashboardSection) -> some View {
        Button { bridge.send(.selectSection(section)) } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
                Text(title).font(.caption2).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(GlassRemoteButton())
        .accessibilityIdentifier("phone.mouse.section.\(section.rawValue)")
    }

    private func actionButton(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 15, weight: .semibold))
                Text(title).font(.system(size: 9, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(GlassRemoteButton())
    }

    private func commandButton(_ symbol: String, _ title: String, _ command: CarMouseBridge.NavigationCommand) -> some View {
        Button { bridge.send(.navigate(command)) } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
                Text(title).font(.caption2).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 45)
        }
        .buttonStyle(GlassRemoteButton())
    }

    private func directionButton(_ symbol: String, dx: CGFloat, dy: CGFloat) -> some View {
        Button { bridge.send(.move(CGPoint(x: dx, y: dy))) } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(GlassRemoteButton())
        .accessibilityLabel(tr("تحريك المؤشر", "Move pointer"))
    }

    private func scrollButton(_ symbol: String, _ title: String, dy: CGFloat) -> some View {
        Button { bridge.send(.scroll(CGPoint(x: 0, y: dy))) } label: {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 38)
        }
        .buttonStyle(GlassRemoteButton())
    }
}

private struct GlassRemoteButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.wdAccent)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(.white.opacity(configuration.isPressed ? 0.3 : 0.13), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
