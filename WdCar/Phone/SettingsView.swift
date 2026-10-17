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
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(tr("العرض", "Display")) {
                    Picker(tr("اللغة", "Language"), selection: $language) {
                        ForEach(AppLanguage.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    Picker(tr("وضع العرض", "Appearance"), selection: $appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                }

                Section {
                    LabeledContent(tr("الحالة", "Status"), value: app.carStatusText)
                    LabeledContent(tr("الفيديو في السيارة", "Video in car"), value: app.carVideoText)
                    LabeledContent(tr("شاشة السيارة", "Car screen"), value: app.carScreenText)
                    Button(tr("تشغيل المتصفح على شاشة السيارة", "Show browser on car screen")) {
                        app.showCarScreenHelp = true
                    }
                    Button(tr("نسخ سجل اتصال CarPlay", "Copy CarPlay connection log")) {
                        UIPasteboard.general.string = WDLog.recentText
                        app.showToast(tr("نُسخ سجل الاتصال", "Connection log copied"))
                    }
                    Toggle(tr("إيقاف الفيديو أثناء القيادة", "Pause video while driving"), isOn: $lockVideo)
                } header: {
                    Text("CarPlay")
                } footer: {
                    Text(tr("في CarPlay يعرض النظام الفيديو فقط والسيارة متوقفة، ويحوّله لصوت أثناء القيادة. حالة دعم الفيديو تصف ما يعلنه النظام لهذه الجلسة. يمكن نسخ سجل الاتصال لتشخيص الشاشة الخارجية.",
                            "In CarPlay the system shows video only while parked and switches to audio while driving. Video support describes what the system reports for this session. Copy the connection log to diagnose the external display."))
                }

                Section(tr("المتصفح", "Browser")) {
                    Toggle(tr("فتح المواقع بنسخة سطح المكتب", "Open sites in desktop mode"), isOn: $phoneDesktop)
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

                Section(tr("حول", "About")) {
                    LabeledContent(tr("التطبيق", "App"), value: "WudCar — وُد كار")
                    LabeledContent(tr("الإصدار", "Version"), value: version)
                    NavigationLink(tr("سياسة الخصوصية", "Privacy Policy")) { LegalTextView(kind: .privacy) }
                    NavigationLink(tr("شروط الاستخدام", "Terms of Use")) { LegalTextView(kind: .terms) }
                }
            }
            .navigationTitle(tr("الإعدادات", "Settings"))
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

/// نص الخصوصية والشروط — يصف ما يفعله التطبيق فعلياً
struct LegalTextView: View {
    enum Kind { case privacy, terms }
    let kind: Kind

    var body: some View {
        ScrollView {
            Text(kind == .privacy ? privacy : terms)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .navigationTitle(kind == .privacy ? tr("سياسة الخصوصية", "Privacy Policy") : tr("شروط الاستخدام", "Terms of Use"))
    }

    private var privacy: String {
        tr("""
        • لا يجمع WudCar أي بيانات شخصية ولا يرسلها إلى خوادمنا، ولا يحتوي على إعلانات أو أدوات تتبع.
        • الاختصارات وعلامات التبويب والإعدادات تُحفظ على جهازك فقط.
        • بيانات حسابات Xtream تُحفظ على جهازك، وكلمات المرور في Keychain.
        • عند تصفح المواقع أو الاتصال بسيرفر IPTV، تتعامل مع تلك الجهات مباشرة وتخضع لسياساتها.
        • الموقع الجغرافي يُستخدم على الجهاز فقط لمعرفة حركة السيارة وإيقاف الفيديو، ولا يُحفظ ولا يُرسل.
        • الميكروفون والتعرف على الكلام يُستخدمان فقط عند الضغط على زر البحث الصوتي.
        """, """
        • WudCar does not collect personal data or send it to our servers, and contains no ads or trackers.
        • Shortcuts, tabs and settings are stored on your device only.
        • Xtream account details are stored on your device, with passwords in the Keychain.
        • When you browse websites or connect to an IPTV server, you deal with those services directly under their policies.
        • Location is used on-device only to detect vehicle movement and pause video; it is never stored or sent.
        • The microphone and speech recognition are used only when you tap voice search.
        """)
    }

    private var terms: String {
        tr("""
        • WudCar أداة تصفح وتشغيل فقط، ولا يوفر أي محتوى ولا يستضيفه.
        • أنت مسؤول عن امتلاك حق الوصول للمواقع والحسابات والقوائم التي تضيفها.
        • لا تشاهد الفيديو أثناء القيادة. التزم بأنظمة المرور في بلدك.
        • التطبيق مقدّم "كما هو" دون ضمانات.
        """, """
        • WudCar is only a browsing and playback tool; it does not provide or host any content.
        • You are responsible for having the right to access the sites, accounts and playlists you add.
        • Do not watch video while driving. Follow the traffic laws of your country.
        • The app is provided "as is" without warranties.
        """)
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
