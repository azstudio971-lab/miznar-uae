import SwiftUI
import WebKit

/// متصفح الهاتف — يشبه سفاري: اختصارات، تبويبات، شريط عنوان بالأسفل، وزر إرسال الموقع للسيارة.
struct PhoneBrowserScreen: View {
    @EnvironmentObject private var app: AppState
    @ObservedObject private var store = TabStore.phone

    @State private var showTabs = false
    @State private var showManage = false
    @State private var addShortcut: ShortcutDraft?
    @State private var isEditingURL = false
    @State private var urlText = ""
    @FocusState private var urlFieldFocused: Bool

    private var activeSession: TabSession? {
        guard let tab = store.activeTab, tab.url != nil else { return nil }
        return WebViewPool.phone.session(for: tab.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                if let session = activeSession {
                    PhoneWebPage(session: session)
                } else {
                    ShortcutsGridView(
                        onOpen: { open($0) },
                        onSendToCar: { sendToCar($0) },
                        onAdd: { addShortcut = ShortcutDraft() },
                        onEdit: { addShortcut = ShortcutDraft(editing: $0) }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let session = activeSession {
                SessionObserver(session: session) { bottomBar($0) }
            } else {
                bottomBar(nil)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .environment(\.colorScheme, .dark) // المتصفح داكن دائماً مثل شاشة السيارة
        .sheet(isPresented: $showTabs) {
            TabsSwitcherView(initialSide: .phone)
        }
        .sheet(isPresented: $showManage) {
            ManageShortcutsView()
        }
        .sheet(item: $addShortcut) { draft in
            ShortcutEditorSheet(draft: draft)
        }
    }

    // MARK: الرأس

    private var header: some View {
        HStack(spacing: 10) {
            CircleIconButton(action: { showManage = true }) {
                Image(systemName: "list.bullet")
            }
            Spacer()
            Text(tr("الترفيه", "Entertainment"))
                .font(.title2.bold())
                .foregroundStyle(.white)
            Spacer()
            AirPlayButton()
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color(white: 0.13)))
            CircleIconButton(action: {
                if let url = store.activeTab?.url { sendToCar(url) }
            }) {
                SendToCarIcon()
            }
            .opacity(store.activeTab?.url == nil ? 0.4 : 1)
            .disabled(store.activeTab?.url == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: الشريط السفلي

    private func bottomBar(_ session: TabSession?) -> some View {
        HStack(spacing: 10) {
            Button {
                session?.takeSnapshot()
                showTabs = true
            } label: {
                TabsCountIcon(count: store.tabs.count)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color(white: 0.13)))
            }
            .buttonStyle(.plain)

            urlCapsule(session)

            Button {
                if let session, session.canGoBack { session.goBack() } else { goHome() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(session == nil ? .gray : .white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color(white: 0.13)))
            }
            .buttonStyle(.plain)
            .disabled(session == nil)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder
    private func urlCapsule(_ session: TabSession?) -> some View {
        HStack(spacing: 8) {
            if isEditingURL {
                TextField(tr("ابحث أو أدخل موقعًا", "Search or enter website"), text: $urlText)
                    .focused($urlFieldFocused)
                    .keyboardType(.webSearch)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(submitURL)
                    .foregroundStyle(.white)
                Button(tr("إلغاء", "Cancel")) { isEditingURL = false }
                    .foregroundStyle(Color.wdAccent)
            } else {
                Button {
                    guard let session else { return }
                    if session.isLoading { session.stopLoading() } else { session.reload() }
                } label: {
                    Image(systemName: session?.isLoading == true ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(session == nil)

                Text(store.activeTab?.url?.host ?? tr("ابحث أو أدخل موقعًا", "Search or enter website"))
                    .font(.system(size: 19))
                    .foregroundStyle(store.activeTab?.url == nil ? .gray : .white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: startEditing)

                pageMenu(session)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Capsule().fill(Color(white: 0.13)))
        .overlay(alignment: .bottom) {
            if let session, session.isLoading {
                GeometryReader { geo in
                    Capsule()
                        .fill(Color.wdAccent)
                        .frame(width: geo.size.width * session.progress, height: 3)
                }
                .frame(height: 3)
                .padding(.horizontal, 22)
            }
        }
    }

    private func pageMenu(_ session: TabSession?) -> some View {
        Menu {
            if let session {
                Section(tr("حجم النص", "Text size")) {
                    Button { session.adjustZoom(by: 0.1) } label: { Label(tr("تكبير", "Larger"), systemImage: "plus.magnifyingglass") }
                    Button { session.adjustZoom(by: -0.1) } label: { Label(tr("تصغير", "Smaller"), systemImage: "minus.magnifyingglass") }
                    Button { session.resetZoom() } label: { Label("100%", systemImage: "textformat.size") }
                }
                Button {
                    session.setDesktopMode(!session.isDesktopMode)
                } label: {
                    Label(session.isDesktopMode ? tr("طلب موقع ويب للجوال", "Request mobile website") : tr("طلب موقع سطح المكتب", "Request desktop website"),
                          systemImage: session.isDesktopMode ? "iphone" : "desktopcomputer")
                }
                Button {
                    addShortcut = ShortcutDraft(
                        name: store.activeTab?.displayTitle ?? "",
                        url: store.activeTab?.url?.absoluteString ?? ""
                    )
                } label: { Label(tr("حفظ في الاختصارات", "Save to shortcuts"), systemImage: "bookmark") }
                Button {
                    if let url = store.activeTab?.url { sendToCar(url) }
                } label: { Label(tr("فتح في السيارة", "Open in car"), systemImage: "car") }
            }
            Button { goHome() } label: { Label(tr("الرئيسية", "Home"), systemImage: "house") }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 36, height: 44)
        }
    }

    // MARK: الإجراءات

    private func open(_ url: URL) {
        store.open(url, inNewTab: false)
    }

    private func sendToCar(_ url: URL) {
        let wasFull = TabStore.car.isFull
        TabStore.car.newTab(url: url)
        if !app.isCarConnected {
            app.showToast(tr("سيظهر في السيارة عند الاتصال", "Will appear in the car when connected"))
        } else if wasFull {
            app.showToast(tr("تبويبات السيارة ممتلئة (8) — فُتح في التبويب الحالي", "Car tabs are full (8) — opened in current tab"))
        } else {
            app.showToast(tr("تم الإرسال إلى السيارة 🚗", "Sent to the car 🚗"))
        }
    }

    private func goHome() {
        if let id = store.activeID { store.clear(id) }
        isEditingURL = false
    }

    private func startEditing() {
        urlText = store.activeTab?.url?.absoluteString ?? ""
        isEditingURL = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { urlFieldFocused = true }
    }

    private func submitURL() {
        if let url = URLInput.resolve(urlText) { open(url) }
        isEditingURL = false
    }
}

// MARK: - صفحة الويب

struct PhoneWebPage: View {
    @ObservedObject var session: TabSession

    var body: some View {
        WebViewHost(webView: session.webView)
            .background(Color.black)
    }
}

/// يعرض WKWebView موجود مسبقاً داخل SwiftUI (الجلسات تبقى حيّة عند تبديل التبويبات)
struct WebViewHost: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        attach(to: container)
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        if webView.superview !== container {
            container.subviews.forEach { $0.removeFromSuperview() }
            attach(to: container)
        }
    }

    private func attach(to container: UIView) {
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
    }
}

/// يعيد رسم المحتوى عند تغيّر حالة الجلسة (التحميل، الرجوع...)
struct SessionObserver<Content: View>: View {
    @ObservedObject var session: TabSession
    @ViewBuilder let content: (TabSession) -> Content

    var body: some View { content(session) }
}

struct TabsCountIcon: View {
    let count: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(0.5), lineWidth: 1.6)
                .frame(width: 20, height: 20)
                .offset(x: -3, y: -3)
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(white: 0.13))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white, lineWidth: 1.6))
                .frame(width: 20, height: 20)
                .offset(x: 2, y: 2)
            Text("\(count)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: 2, y: 2)
        }
    }
}
