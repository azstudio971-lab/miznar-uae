import SwiftUI

/// التحديث 3: نافذة على الهاتف لتشغيل المتصفح على شاشة السيارة عبر AirPlay (شاشة خارجية)
struct CarScreenSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: app.carScreenActive ? "checkmark.circle.fill" : "car.side.front.open")
                    .font(.system(size: 54))
                    .foregroundStyle(app.carScreenActive ? Color.green : Color.wdAccent)
                    .padding(.top, 24)

                Label(app.isCarConnected ? tr("متصل", "Connected") : tr("غير متصل", "Not connected"), systemImage: "circle.fill")
                    .foregroundStyle(app.isCarConnected ? Color.green : Color(.systemGray))
                    .font(.title3.bold())

                if !app.carScreenActive {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(tr("اضغط زر AirPlay بالأسفل", "Tap the AirPlay button below"), systemImage: "1.circle")
                        Label(tr("اختر شاشة السيارة من القائمة", "Choose the car display from the list"), systemImage: "2.circle")
                        Label(tr("سيظهر مشغّل الويب على الشاشة والسيارة متوقفة", "WudCar Web Player appears on the screen while parked"), systemImage: "3.circle")
                    }
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                    AirPlayButton()
                        .frame(width: 88, height: 88)
                        .background(Circle().fill(Color.wdNavy))
                }

                Spacer()
            }
            .navigationTitle(tr("عرض على شاشة السيارة", "Show on car display"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("تم", "Done")) { dismiss() }
                }
            }
        }
    }
}
