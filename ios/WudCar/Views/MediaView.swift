import SwiftUI
import WebKit

struct MediaView: View {
    @EnvironmentObject private var state: AppState
    @State private var showingBrowser = false
    @AppStorage("wudcar.v3.browser.starters.v1") private var seeded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button { showingBrowser = true } label: {
                    HStack(spacing: 18) {
                        Image(systemName: "safari").font(.system(size: 42, weight: .light))
                            .foregroundStyle(Color(red: 0.12, green: 0.56, blue: 0.52))
                        VStack(alignment: .leading, spacing: 7) {
                            Text(state.text("المتصفح", "Browser")).font(.title2.bold())
                            Text(state.text("تصفّح مواقعك واحفظ اختصاراتك", "Browse your websites and save shortcuts"))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.forward").foregroundStyle(.secondary)
                    }.padding(24).frame(maxWidth: .infinity, minHeight: 136)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
                }.buttonStyle(.plain).accessibilityIdentifier("entertainment.browser")
                HStack(spacing: 14) {
                    Image("BrandIcon").resizable().scaledToFit().frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 10))
                    Text(state.text("يوتيوب وتيك توك، في مكان واحد.", "YouTube and TikTok, in one place."))
                        .font(.subheadline).foregroundStyle(.secondary)
                }.padding(.horizontal, 8)
            }.padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(state.text("الترفيه", "Entertainment"))
        .fullScreenCover(isPresented: $showingBrowser) { EntertainmentBrowser() }
        .onAppear { seedShortcuts() }
    }

    private func seedShortcuts() {
        guard !seeded else { return }
        // Migrate only the untouched, generated Shahid default. Preserve edited/user sources.
        state.sources.removeAll {
            $0.id == "wudcar-shahid" && $0.name == "Shahid" && $0.url == "https://shahid.mbc.net" &&
            !$0.favorite && $0.iconURL == nil
        }
        for source in [
            MediaSource(id: "wudcar-youtube", name: "YouTube", url: "https://www.youtube.com", type: "website", mediaKind: "video"),
            MediaSource(id: "wudcar-tiktok", name: "TikTok", url: "https://www.tiktok.com", type: "website", mediaKind: "video")
        ] where !state.sources.contains(where: {
            $0.type == "website" && BrowserPolicy.normalizedHost(URL(string: $0.url)) == BrowserPolicy.normalizedHost(URL(string: source.url))
        }) { state.sources.append(source) }
        seeded = true
    }
}

struct WebsiteShortcutIcon: View {
    let source: MediaSource
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(Color(red: 0.04, green: 0.30, blue: 0.36))
            if let value = source.iconURL, let url = BrowserPolicy.websiteURL(value) {
                AsyncImage(url: url) { image in image.resizable().scaledToFit() }
                    placeholder: { Image(systemName: "globe").font(.title).foregroundStyle(.white) }.padding(8)
            } else if let asset = BrowserPolicy.siteAsset(for: URL(string: source.url)) {
                Image(asset).resizable().scaledToFit()
            } else {
                Text(String(source.name.prefix(2))).font(.title2.bold()).foregroundStyle(.white)
            }
        }.clipShape(RoundedRectangle(cornerRadius: 18)).accessibilityHidden(true)
    }
}

struct WebsiteShortcutEditor: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State var source: MediaSource
    @State private var icon = ""
    var body: some View {
        NavigationStack {
            Form {
                TextField(state.text("الاسم", "Name"), text: $source.name).accessibilityIdentifier("shortcut.name")
                TextField("https://", text: $source.url)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("shortcut.url")
                TextField(state.text("رابط صورة الأيقونة — اختياري", "Icon image URL — optional"), text: $icon)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Text(state.text("استخدم رابط HTTPS مباشرًا لصورة الأيقونة.", "Use a direct HTTPS image URL for your icon."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle(state.text("اختصار موقع", "Website shortcut"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(state.text("إلغاء", "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(state.text("حفظ", "Save")) {
                        guard let url = BrowserPolicy.websiteURL(source.url) else { return }
                        source.name = String(source.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
                        source.url = url.absoluteString
                        source.iconURL = icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : BrowserPolicy.websiteURL(icon)?.absoluteString
                        if let index = state.sources.firstIndex(where: { $0.id == source.id }) { state.sources[index] = source }
                        else { state.sources.append(source) }
                        dismiss()
                    }.disabled(source.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                               BrowserPolicy.websiteURL(source.url) == nil ||
                               (!icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && BrowserPolicy.websiteURL(icon) == nil))
                        .accessibilityIdentifier("shortcut.save")
                }
            }.onAppear { icon = source.iconURL ?? "" }
        }
    }
}

// Phone/iPad browser only. CarPlay templates cannot host this UIViewRepresentable.
struct EntertainmentWebSurface: UIViewRepresentable {
    let tab: EntertainmentBrowserTab
    func makeUIView(context: Context) -> WKWebView { tab.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct EntertainmentBrowser: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = EntertainmentBrowserStore.shared
    @State private var showingTabs = false

    var body: some View {
        BrowserTabView(tab: store.selected, store: store, showingTabs: $showingTabs) {
            store.suspendAll()
            dismiss()
        }
        .sheet(isPresented: $showingTabs) { BrowserTabsView(store: store) }
        .onChange(of: showingTabs) { _, visible in
            if visible { store.suspendAll() } else { store.selected.activate() }
        }
        .onAppear {
            store.selected.activate()
            #if DEBUG
            if AppConfiguration.browserUITesting && ProcessInfo.processInfo.arguments.contains("--browser-fixture") {
                store.selected.openTestFixture()
            }
            #endif
        }
        .onDisappear { store.suspendAll() }
    }
}

private struct BrowserTabView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var tab: EntertainmentBrowserTab
    @ObservedObject var store: EntertainmentBrowserStore
    @Binding var showingTabs: Bool
    let close: () -> Void
    @State private var input = ""
    @State private var editing: MediaSource?
    @State private var expanded = false
    @FocusState private var addressFocused: Bool

    private var shortcuts: [MediaSource] { state.sources.filter { $0.type == "website" } }

    var body: some View {
        VStack(spacing: 0) {
            if !expanded { header }
            if tab.loading { ProgressView(value: tab.progress).tint(.accentColor).accessibilityLabel(state.text("تحميل الصفحة", "Loading page")) }
            if let error = tab.error {
                HStack {
                    Text(error).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("browser.error")
                    Button(state.text("إعادة المحاولة", "Retry")) {
                        if tab.showingHome { navigate() } else { tab.reload() }
                    }
                    Button { tab.error = nil } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(state.text("إخفاء التنبيه", "Dismiss notice"))
                }.padding(12).background(Color.orange.opacity(0.12))
            }
            ZStack(alignment: .topTrailing) {
                EntertainmentWebSurface(tab: tab).id(tab.id)
                    .opacity(tab.showingHome ? 0 : 1).allowsHitTesting(!tab.showingHome)
                    .accessibilityHidden(tab.showingHome)
                if tab.showingHome { startPage }
                if expanded {
                    Button { expanded = false } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left").padding(14).background(.regularMaterial, in: Circle())
                    }.padding(12).accessibilityLabel(state.text("إظهار أدوات المتصفح", "Show browser controls"))
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            if !expanded { toolbar }
        }
        .background(Color(uiColor: .systemBackground))
        .sheet(item: $editing) { source in WebsiteShortcutEditor(source: source) }
        .onChange(of: tab.address) { _, value in if !addressFocused { input = value } }
        .onChange(of: tab.id) { _, _ in input = tab.address; addressFocused = false; expanded = false }
        .onAppear { input = tab.address }
    }

    private var header: some View {
        HStack {
            Image("BrandIcon").resizable().scaledToFit().frame(width: 32, height: 32).clipShape(RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)
            Spacer()
            Text(state.text("المتصفح", "Browser")).font(.headline)
            Spacer()
            Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44).background(.quaternary, in: Circle()) }
                .accessibilityLabel(state.text("إغلاق المتصفح", "Close browser")).accessibilityIdentifier("browser.close")
        }.padding(.horizontal, 18).padding(.vertical, 6)
    }

    private var startPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(state.text("مواقعك المفضلة", "Your websites")).font(.title2.bold()).padding(.top, 24)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 18)], spacing: 28) {
                    ForEach(shortcuts) { source in
                        Button { addressFocused = false; tab.open(source.url) } label: {
                            VStack(spacing: 12) {
                                WebsiteShortcutIcon(source: source).frame(width: 72, height: 72)
                                Text(source.name).font(.subheadline).lineLimit(2).foregroundStyle(.primary)
                            }.frame(maxWidth: .infinity, minHeight: 108)
                        }.buttonStyle(.plain).accessibilityIdentifier("browser.site.\(source.id)")
                        .contextMenu {
                            Button(state.text("فتح في تبويب جديد", "Open in new tab")) { store.addTab()?.open(source.url) }
                                .disabled(!BrowserPolicy.canAddTab(count: store.tabs.count))
                            Button(state.text("تعديل", "Edit")) { editing = source }
                            Button(state.text("حذف", "Delete"), role: .destructive) { state.sources.removeAll { $0.id == source.id } }
                        }
                    }
                }
                Button {
                    editing = MediaSource(name: "", url: "https://", type: "website", mediaKind: "video")
                } label: { Label(state.text("إضافة اختصار", "Add shortcut"), systemImage: "plus.circle") }
                    .padding(.vertical, 10).accessibilityIdentifier("browser.addShortcut")
            }.padding(.horizontal, 24).padding(.bottom, 30)
        }.background(Color(uiColor: .systemBackground))
    }

    private var toolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Button {
                    addressFocused = false
                    tab.captureThumbnail()
                    showingTabs = true
                } label: {
                    ZStack {
                        Image(systemName: "square.on.square").font(.title2)
                        Text("\(store.tabs.count)").font(.system(size: 10, weight: .bold)).offset(x: 2, y: 3)
                    }.frame(width: 44, height: 44)
                }.accessibilityLabel(state.text("التبويبات", "Tabs")).accessibilityValue("\(store.tabs.count)")
                    .accessibilityIdentifier("browser.tabs")
                HStack(spacing: 5) {
                    Image(systemName: tab.showingHome ? "magnifyingglass" : "lock.fill").font(.caption).foregroundStyle(.secondary)
                    TextField(state.text("ابحث أو أدخل موقعًا", "Search or enter a website"), text: $input)
                        .keyboardType(.webSearch).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .submitLabel(.go).focused($addressFocused).onSubmit { navigate() }
                        .environment(\.layoutDirection, .leftToRight)
                        .accessibilityIdentifier("browser.address")
                    if addressFocused {
                        Button { navigate() } label: { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                            .accessibilityLabel(state.text("فتح", "Go")).accessibilityIdentifier("browser.go")
                    } else { browserMenu }
                }.padding(.horizontal, 12).frame(minHeight: 48)
                    .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
            }
            HStack {
                tool("chevron.backward", state.text("رجوع", "Back"), "browser.back") { tab.webView.goBack() }.disabled(!tab.canGoBack)
                Spacer()
                tool("chevron.forward", state.text("تقدم", "Forward"), "browser.forward") { tab.webView.goForward() }.disabled(!tab.canGoForward)
                Spacer()
                tool("house", state.text("الرئيسية", "Home"), "browser.home") { addressFocused = false; tab.home() }
                Spacer()
                tool(tab.loading ? "xmark" : "arrow.clockwise", state.text("تحديث أو إيقاف", "Reload or stop"), "browser.reload") {
                    if tab.loading { tab.webView.stopLoading() } else { tab.reload() }
                }.disabled(tab.showingHome)
                Spacer()
                tool("arrow.up.left.and.arrow.down.right", state.text("توسيع الصفحة", "Expand page"), "browser.expand") {
                    addressFocused = false; expanded = true
                }.disabled(tab.showingHome)
            }.padding(.horizontal, 8)
        }.padding(.horizontal, 12).padding(.top, 8).background(.bar)
    }

    private var browserMenu: some View {
        Menu {
            Button(state.text("تكبير", "Zoom in")) { tab.setZoom(tab.zoom + 0.1) }.disabled(tab.zoom >= BrowserPolicy.maximumZoom)
            Button("\(Int((tab.zoom * 100).rounded()))% · " + state.text("إعادة الحجم", "Reset zoom")) { tab.setZoom(1) }
            Button(state.text("تصغير", "Zoom out")) { tab.setZoom(tab.zoom - 0.1) }.disabled(tab.zoom <= BrowserPolicy.minimumZoom)
            Divider()
            Button {
                let existing = shortcuts.first { $0.url == tab.address }
                editing = existing ?? MediaSource(name: tab.title.isEmpty ? (URL(string: tab.address)?.host ?? "") : tab.title,
                                                   url: tab.address, type: "website", mediaKind: "video", favorite: true)
            } label: { Label(state.text("حفظ اختصار", "Save shortcut"), systemImage: "bookmark") }
                .disabled(tab.showingHome || BrowserPolicy.websiteURL(tab.address) == nil)
            Button { tab.setDesktop(!tab.desktop) } label: {
                Label(tab.desktop ? state.text("طلب موقع ويب للجوال", "Request mobile website") : state.text("طلب موقع سطح المكتب", "Request desktop website"),
                      systemImage: tab.desktop ? "iphone" : "desktopcomputer")
            }
            Button { tab.home() } label: { Label(state.text("الرئيسية", "Home"), systemImage: "house") }
        } label: { Image(systemName: "line.3.horizontal").frame(width: 36, height: 44) }
            .accessibilityLabel(state.text("خيارات المتصفح", "Browser options")).accessibilityIdentifier("browser.menu")
    }

    private func tool(_ symbol: String, _ title: String, _ id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 44, height: 44) }
            .accessibilityLabel(title).accessibilityIdentifier(id)
    }
    private func navigate() { addressFocused = false; tab.open(input) }
}

private struct BrowserTabsView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: EntertainmentBrowserStore
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], spacing: 16) {
                    ForEach(store.tabs) { tab in
                        BrowserTabCard(tab: tab, selected: tab.id == store.selectedID,
                                       select: { store.select(tab.id); dismiss() }, close: { store.close(tab.id) })
                    }
                }.padding()
            }.background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle(state.text("علامات التبويب", "Tabs"))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button(state.text("تم", "Done")) { dismiss() }.accessibilityIdentifier("tabs.done") }
                    ToolbarItem(placement: .bottomBar) {
                        HStack {
                            Text("\(store.tabs.count) / \(BrowserPolicy.maximumTabs)").foregroundStyle(.secondary)
                            Spacer()
                            Button { _ = store.addTab(); dismiss() } label: { Image(systemName: "plus") }
                                .disabled(!BrowserPolicy.canAddTab(count: store.tabs.count))
                                .accessibilityLabel(state.text("تبويب جديد", "New tab")).accessibilityIdentifier("tabs.add")
                        }
                    }
                }
        }
    }
}

private struct BrowserTabCard: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var tab: EntertainmentBrowserTab
    let selected: Bool
    let select: () -> Void
    let close: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                Button(action: select) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20).fill(Color(uiColor: .secondarySystemGroupedBackground))
                        if let image = tab.thumbnail {
                            Image(uiImage: image).resizable().scaledToFill().frame(height: 118).clipped()
                        } else {
                            Image("BrandIcon").resizable().scaledToFit().frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }.frame(height: 118).clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? Color.accentColor : .clear, lineWidth: 3))
                }.buttonStyle(.plain).accessibilityLabel(tab.title.isEmpty ? state.text("الرئيسية", "Home") : tab.title)
                Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44).background(.regularMaterial, in: Circle()) }
                    .padding(4).accessibilityLabel(state.text("إغلاق التبويب", "Close tab")).accessibilityIdentifier("tabs.close")
            }
            Text(tab.title.isEmpty ? state.text("الرئيسية", "Home") : tab.title).font(.caption).lineLimit(2)
        }
    }
}
