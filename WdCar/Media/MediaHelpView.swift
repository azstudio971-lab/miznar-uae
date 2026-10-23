import SwiftUI
import UIKit
struct MediaHelpView: View {
    var body: some View {
        List {
            Section(tr("من أين أحصل على محتوى؟", "Where do I get content?")) {
                Text(tr("لا يوفّر WudCar قنوات أو اشتراكات محتوى. استخدم ملفاتك أو قوائم وخوادم تملك حق الوصول إليها.", "WudCar provides no channels or content subscriptions. Use your files or playlists and servers you are entitled to access."))
            }
            Section(tr("لماذا يعمل الصوت فقط في السيارة؟", "Why does only audio work in my car?")) {
                Text(tr("عرض الفيديو يعتمد على دعم السيارة وAirPlay وسماح النظام أثناء التوقف. فك الترميز البرمجي متاح على الهاتف فقط.", "Video depends on vehicle and AirPlay support and system permission while parked. Software decoding is available on iPhone only."))
            }
            Section(tr("لماذا لا تظهر الترجمة الخارجية على التلفزيون؟", "Why are external subtitles missing on TV?")) {
                Text(tr("تُرسم الترجمة الخارجية على الهاتف. للشاشة البعيدة استخدم مسار ترجمة مدمجاً في مصدر الوسائط.", "External subtitles render on iPhone. For a remote display, use an embedded subtitle track in the media source."))
            }
            Section(tr("هل تُحفظ بيانات دخولي؟", "Where are my credentials stored?")) {
                Text(tr("على هذا الجهاز فقط في Keychain. يتصل التطبيق بخادمك مباشرة ولا يرسل بيانات المصادر إلى خوادم WudCar.", "On this device only in Keychain. The app connects directly to your server and does not send source data to WudCar servers."))
            }
            Section(tr("الدعم", "Support")) {
                Text("az.studio971@gmail.com")
                Button(tr("نسخ بريد الدعم", "Copy support email")) {
                    UIPasteboard.general.string = "az.studio971@gmail.com"
                }
                Link(tr("موقع WudCar", "WudCar website"), destination: URL(string: "https://wudcar.netlify.app/")!)
            }
        }.navigationTitle(tr("المساعدة", "Help"))
    }
}
