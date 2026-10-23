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
        return short
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(tr("حالة الاشتراك", "Subscription status")) {
                    NavigationLink(tr("حالة الاشتراك وإدارته", "Subscription status and management")) { SubscriptionView() }
                }

                Section(tr("المشغّل والتحكم", "Player and controls")) {
                    NavigationLink(tr("إعدادات المشغّل", "Player settings")) { MediaSettingsView() }
                    NavigationLink(tr("البث إلى الشاشة • AirPlay", "Send to display • AirPlay")) { SubscriptionGate { MediaCastingView() } }
                    NavigationLink(tr("الماوس", "Mouse")) { SubscriptionGate { CarMousePadView() } }
                }

                Section(tr("العرض", "Display")) {
                    Picker(tr("اللغة", "Language"), selection: $language) {
                        ForEach(AppLanguage.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    Picker(tr("وضع العرض", "Appearance"), selection: $appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                }

                Section {
                    Toggle(tr("إيقاف الفيديو أثناء القيادة", "Pause video while driving"), isOn: $lockVideo)
                } header: {
                    Text("CarPlay")
                } footer: {
                    Text(tr("عند تفعيل هذا الخيار يتوقف الفيديو إذا رصد التطبيق حركة السيارة. يظل أي منع يفرضه النظام سارياً.",
                            "When enabled, video pauses if the app detects vehicle movement. System-enforced restrictions always remain in effect."))
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
                    LabeledContent(tr("التطبيق", "App"), value: "WudCar - M3U IPTV")
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

    var privacy: String {
        tr("""
        • WudCar مشغّل فيديو ووسائط لقوائم M3U/M3U8 وحسابات Xtream وروابط الوسائط والملفات التي يختارها المستخدم. لا نوفر قنوات أو أفلامًا أو اشتراكات IPTV ولا نستضيف المحتوى.
        • مكتبة الوسائط والمفضلة وسجل المشاهدة ومواضع الاستئناف تُحفظ محليًا. تُحفظ بيانات الدخول وروابط الوسائط في Keychain.
        • الصور والملفات التي تختارها عبر أدوات iPhone الرسمية تُنسخ إلى مساحة التطبيق للتشغيل المحلي. إزالة النسخة من المكتبة لا تحذف الأصل من هاتفك.
        • لا نرسل مكتبتك أو ملفاتك المستوردة إلى خوادمنا، ولا يحتوي التطبيق على إعلانات أو أدوات تتبع.
        • الاختصارات وعلامات التبويب والإعدادات تُحفظ على جهازك فقط.
        • بيانات حسابات Xtream وقوائم M3U تُحفظ على جهازك، وبيانات الدخول وروابط القوائم في Keychain.
        • عند تصفح المواقع أو الاتصال بسيرفر IPTV، تتعامل مع تلك الجهات مباشرة وتخضع لسياساتها.
        • عند البث عبر AirPlay، يُرسل المحتوى إلى الجهاز الذي تختاره وفق إمكانات النظام والمصدر. هذه الوظيفة ليست عكسًا كاملًا لشاشة الهاتف أو استقبالًا للبث.
        • مشتريات اشتراك التطبيق تُعالج من خلال Apple؛ الاشتراك لا يتضمن اشتراك محتوى.
        • الموقع الجغرافي يُستخدم على الجهاز فقط لمعرفة حركة السيارة وإيقاف الفيديو، ولا يُحفظ ولا يُرسل.
        • الميكروفون والتعرف على الكلام يُستخدمان فقط عند الضغط على زر البحث الصوتي.
        """, """
        • WudCar is a video and media player for user-supplied M3U/M3U8 playlists, Xtream accounts, media URLs and selected files. We do not provide channels, movies or IPTV content subscriptions, or host content.
        • Library metadata, favorites, viewing history and resume positions are stored locally. Credentials and media URLs are stored in the Keychain.
        • Photos and files selected with official iPhone pickers are copied into app storage for local playback. Removing an app copy does not delete the original from your phone.
        • We do not upload your library or imported files to our servers. The app contains no ads or tracking tools.
        • Shortcuts, tabs and settings are stored on your device only.
        • Xtream accounts and M3U playlists are stored on your device; credentials and playlist URLs are kept in the Keychain.
        • When you browse websites or connect to an IPTV server, you deal with those services directly under their policies.
        • AirPlay sends media to the device you select, subject to system and source support. This is not full-screen mirroring or an incoming cast receiver.
        • App subscription purchases are processed by Apple; they do not include a content subscription.
        • Location is used on-device only to detect vehicle movement and pause video; it is never stored or sent.
        • The microphone and speech recognition are used only when you tap voice search.
        """)
    }

    var terms: String {
        tr("""
        • WudCar مشغّل فيديو ووسائط، يدعم قوائم M3U/M3U8 وحسابات Xtream وروابط الإنترنت والملفات المستوردة، ويتضمن متصفحًا. لا يوفر التطبيق المحتوى أو اشتراكات IPTV ولا يستضيفها.
        • الملفات المستوردة المحفوظة محليًا يمكن تشغيلها دون إنترنت؛ البث من الإنترنت يحتاج اتصالًا ومصدرًا متاحًا. يختلف دعم الصيغ والترجمة وAirPlay حسب المصدر والجهاز.
        • عرض الفيديو في السيارة يعتمد على دعم النظام والسيارة وحالة السماح. وجود صلاحيات CarPlay لا يضمن عرض الفيديو في كل سيارة. لا توجد ميزة لعكس شاشة الهاتف بالكامل في هذا الإصدار.
        • أنت مسؤول عن امتلاك حق الوصول للمواقع والحسابات والقوائم التي تضيفها.
        • لا تشاهد الفيديو أثناء القيادة. التزم بأنظمة المرور في بلدك.
        • التطبيق مقدّم "كما هو" دون ضمانات.
        """, """
        • WudCar is a video and media player for M3U/M3U8 playlists, Xtream accounts, internet URLs and imported files, with browser functionality. It does not provide or host content or IPTV subscriptions.
        • Locally saved imported files can play offline; internet streaming requires connectivity and an available source. Format, subtitle and AirPlay support depend on the source and device.
        • In-car video depends on system and vehicle support and current permission. CarPlay entitlements do not guarantee video on every vehicle. Full iPhone screen mirroring is not available in this release.
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

