import SwiftUI

/// التحديث 3: نافذة على الهاتف لتشغيل المتصفح على شاشة السيارة عبر AirPlay (شاشة خارجية)
struct CarScreenSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var launcher = CarScreenLauncher.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: app.carScreenActive ? "checkmark.circle.fill" : "car.side.front.open")
                    .font(.system(size: 54))
                    .foregroundStyle(app.carScreenActive ? Color.green : Color.wdAccent)
                    .padding(.top, 24)

                Text(app.carScreenActive ? tr("المتصفح يعمل على شاشة السيارة", "The browser is on the car screen")
                                         : tr("اعرض المتصفح على شاشة السيارة", "Show the browser on the car screen"))
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                if !app.carScreenActive {
                    Button(tr("فتح المتصفح على الشاشة الخارجية", "Open browser on external display")) {
                        launcher.launch()
                    }.buttonStyle(.borderedProminent)
                    Text(tr("المكتبة والمفضلة متاحتان في قوالب CarPlay. المتصفح مسار منفصل ويحتاج شاشة خارجية متوافقة؛ اختيار AirPlay وحده لا يضمن عرضه.", "Library and Favorites use CarPlay templates. The browser is a separate path requiring a compatible external display; choosing AirPlay alone does not guarantee browser presentation."))
                        .font(.footnote).foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        Label(tr("اضغط زر AirPlay بالأسفل", "Tap the AirPlay button below"), systemImage: "1.circle")
                        Label(tr("اختر شاشة السيارة من القائمة", "Choose the car display from the list"), systemImage: "2.circle")
                        Label(tr("يتوفر العرض حسب دعم السيارة والنظام أثناء الوقوف", "Availability depends on the vehicle and system while parked"), systemImage: "3.circle")
                    }
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                    AirPlayButton()
                        .frame(width: 88, height: 88)
                        .background(Circle().fill(Color.wdNavy))
                } else {
                    Text(app.carScreenText)
                        .foregroundStyle(.secondary)
                    Button(tr("إغلاق المتصفح والعودة إلى CarPlay", "Close browser and return to CarPlay")) { launcher.closeBrowser(); dismiss() }
                }

                Spacer()
            }
            .navigationTitle(tr("شاشة السيارة", "Car screen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("تم", "Done")) { dismiss() }
                }
            }
        }
    }
}

