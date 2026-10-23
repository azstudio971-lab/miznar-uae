import SwiftUI

struct CarScreenSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Label(tr("مشغّل للفيديو والصوت", "Video and audio player"), systemImage: "play.rectangle")
                Text(tr("تستخدم واجهة السيارة قوالب CarPlay الرسمية للمكتبة والمفضلة والقنوات والبث. افتح WudCar من الشاشة الرئيسية للسيارة.", "The car interface uses native CarPlay templates for library, favorites, channels and casting. Open WudCar from the car's Home screen."))
                Text(tr("المتصفح يبقى متاحًا على iPhone. قوالب CarPlay لا تعرض صفحات الويب. لا يُفتح متصفح مخصص فوق واجهة السيارة تلقائيًا.", "The browser remains available on iPhone. CarPlay templates do not display web pages. A custom browser is not automatically opened over the car interface."))
                NavigationLink(tr("البث إلى الشاشة • AirPlay", "Send to display • AirPlay")) { MediaCastingView() }
                NavigationLink(tr("فحص اتصال CarPlay", "CarPlay connection check")) { CarPlayConnectionView() }
            }
            .navigationTitle(tr("شاشة السيارة", "Car screen"))
            .toolbar { Button(tr("تم", "Done")) { dismiss() } }
        }
    }
}
