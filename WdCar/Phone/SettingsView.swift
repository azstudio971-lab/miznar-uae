import SwiftUI
import WebKit
import AVKit

struct SettingsView: View {
    var isSheet = true
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState
    @AppStorage(WDKeys.language) private var language = L10n.language.rawValue
    @AppStorage(WDKeys.appearance) private var appearance = AppAppearance.system.rawValue
    @AppStorage(WDKeys.lockVideoWhileDriving) private var lockVideo = true
    @AppStorage(WDKeys.phoneDesktopMode) private var phoneDesktop = true
    @State private var confirmClear = false
    @State private var confirmReset = false
    @State private var confirmXtream = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        return short + " (" + (info?["CFBundleVersion"] as? String ?? "15") + ")"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(tr("حالة الاشتراك", "Subscription status")) {
                    NavigationLink(tr("حالة الاشتراك وإدارته", "Subscription status and management")) { SubscriptionView() }
                }

                Section(tr("العرض", "Display")) {
                    Picker(tr("اللغة", "Language"), selection: $language) {
                        ForEach(AppLanguage.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    Picker(tr("وضع العرض", "Appearance"), selection: $appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                }

                Section(tr("المشغّل", "Player")) { NavigationLink(tr("إعدادات المشغّل", "Player settings")) { MediaSettingsView() } }

                Section {
                    Toggle(tr("إيقاف الفيديو أثناء القيادة", "Pause video while driving"), isOn: $lockVideo)
                } header: {
                    Text("CarPlay")
                } footer: {
                    Text(tr("عند تفعيل هذا الخيار يتوقف الفيديو إذا رصد التطبيق حركة السيارة. يظل أي منع يفرضه النظام سارياً.",
                            "When enabled, video pauses if the app detects vehicle movement. System-enforced restrictions always remain in effect."))
                    Text(tr("للركاب فقط — لا تشاهد أثناء القيادة.", "For passengers only — never watch while driving."))
                }

                Section(tr("أدوات السيارة", "Car tools")) {
                    NavigationLink(tr("الماوس", "Mouse")) { SubscriptionGate { CarMousePadView() } }
                    NavigationLink(tr("الترفيه ومشغّل الويب", "Entertainment and Web Player")) { SubscriptionGate { PhoneBrowserScreen() } }
                    Toggle(tr("مشغّل الويب: نسخة سطح المكتب", "Web Player: desktop mode"), isOn: $phoneDesktop)
                }

                Section(tr("إدارة البيانات", "Data")) {
                    Button(tr("استعادة الاختصارات الافتراضية", "Restore default shortcuts")) { confirmReset = true }
                    Button(tr("مسح بيانات التصفح وتسجيل الدخول", "Clear browsing data and sign-ins"), role: .destructive) {
                        confirmClear = true
                    }
                    Button(tr("حذف كل حسابات Xtream", "Delete all Xtream accounts"), role: .destructive) {
                        confirmXtream = true
                    }
                }

                Section(tr("المساعدة", "Help")) {
                    NavigationLink(tr("الأسئلة الشائعة", "Frequently asked questions")) { LegalTextView(kind: .faq) }
                    Link(tr("تواصل معنا", "Contact us"), destination: URL(string: "https://wudcar.netlify.app/support/")!)
                }
                Section(tr("القانونية", "Legal")) {
                    ForEach(LegalTextView.Kind.allCases.filter { $0 != .faq }, id: \.self) { kind in NavigationLink(kind.title) { LegalTextView(kind: kind) } }
                }
                Section(tr("حول", "About")) {
                    LabeledContent(tr("التطبيق", "App"), value: "WudCar Media Player")
                    LabeledContent(tr("الإصدار", "Version"), value: version)
                }
            }
            .navigationTitle(tr("الإعدادات — WudCar Media Player", "Settings — WudCar Media Player"))
            .toolbar {
                if isSheet {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(tr("تم", "Done")) { dismiss() }
                    }
                }
            }
            .confirmationDialog(tr("مسح كل بيانات التصفح؟ سيتم تسجيل خروجك من المواقع.",
                                   "Clear all browsing data? You will be signed out of websites."),
                                isPresented: $confirmClear, titleVisibility: .visible) {
                Button(tr("مسح", "Clear"), role: .destructive, action: clearData)
            }
            .confirmationDialog(tr("استعادة الاختصارات الافتراضية؟", "Restore default shortcuts?"),
                                isPresented: $confirmReset, titleVisibility: .visible) {
                Button(tr("استعادة", "Restore"), role: .destructive) { ShortcutStore.shared.resetToDefaults() }
            }
            .confirmationDialog(tr("حذف كل الحسابات وكلمات المرور المحفوظة؟", "Delete all accounts and saved passwords?"),
                                isPresented: $confirmXtream, titleVisibility: .visible) {
                Button(tr("حذف", "Delete"), role: .destructive) {
                    PlaybackManager.shared.stop()
                    XtreamStore.shared.removeAll()
                }
            }
        }
    }

    private func clearData() {
        let store = WKWebsiteDataStore.default()
        store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {
            app.showToast(tr("تم مسح البيانات", "Data cleared"))
        }
    }
}

/// زر AirPlay لبث الفيديو لشاشة السيارة أو التلفزيون
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = true
        picker.tintColor = .white
        picker.activeTintColor = CarUI.accent
        picker.backgroundColor = .clear
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
