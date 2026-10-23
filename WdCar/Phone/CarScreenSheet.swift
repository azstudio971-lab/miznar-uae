import SwiftUI

struct CarScreenSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Label(tr("مشغّل للفيديو والصوت", "Video and audio player"), systemImage: "play.rectangle")
                Text(tr("تستخدم واجهة السيارة قوالب CarPlay الرسمية للمكتبة والمفضلة والقنوات والبث. افتح WudCar من الشاشة الرئيسية للسيارة.", "The car interface uses native CarPlay templates for library, favorites, channels and casting. Open WudCar from the car's Home screen."))
                Text(tr("المفضلة ← المتصفح يطلب واجهة المتصفح السابقة على شاشة خارجية متوافقة عند توفرها. هذه واجهة مخصصة، وليست قالب متصفح رسميًا. اختيار AirPlay لا يضمن أن النظام سيمنح التطبيق شاشة خارجية لعرض المتصفح.", "Favorites → Browser requests the previous browser interface on an app-owned external display when one is available. This custom interface is not an official browser template. Selecting AirPlay does not guarantee an app-owned browser display."))
                Button(tr("طلب فتح المتصفح", "Request browser display")) { CarScreenLauncher.shared.launch() }
                Button(tr("إغلاق شاشة المتصفح", "Close browser display")) { CarScreenLauncher.shared.closeBrowser() }
                AirPlayButton().frame(width: 64, height: 48)
                NavigationLink(tr("البث إلى الشاشة • AirPlay", "Send to display • AirPlay")) { MediaCastingView() }
                NavigationLink(tr("فحص اتصال CarPlay", "CarPlay connection check")) { CarPlayConnectionView() }
            }
            .navigationTitle(tr("شاشة السيارة", "Car screen"))
            .toolbar { Button(tr("تم", "Done")) { dismiss() } }
        }
    }
}
