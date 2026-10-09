import SwiftUI

struct InformationView: View {
    @EnvironmentObject var state: AppState
    @ObservedObject var information = InformationService.shared
    private let prayerNames = ["Fajr":"الفجر","Sunrise":"الشروق","Dhuhr":"الظهر","Asr":"العصر","Maghrib":"المغرب","Isha":"العشاء"]
    var body: some View {
        List {
            Section(state.text("الطقس", "Weather")) {
                if let weather=information.weather,weather.city==state.preferences.city {
                    Label("\(Int(weather.temperature.rounded()))°C · \(weather.city)",systemImage:weather.symbol).font(.title2)
                    if let low=weather.tomorrowLow,let high=weather.tomorrowHigh { Text(state.text("غدًا", "Tomorrow")+": \(Int(low.rounded()))–\(Int(high.rounded()))°C") }
                    Text(state.text("آخر تحديث", "Last updated")+": "+weather.fetchedAt.formatted()).font(.caption)
                    if let url=URL(string:weather.attributionURL) { Link(destination:url) { HStack { if let mark=URL(string:weather.attributionMark) { AsyncImage(url:mark) { image in image.resizable().scaledToFit() } placeholder:{ Text("Apple Weather") }.frame(height:18) };Text(state.text("المصدر والترخيص", "Source and attribution")).font(.caption) } } }
                } else { Text(state.text("لا توجد نتيجة طقس متاحة لهذه المدينة.", "Weather is not available for this city.")) }
                if let error=information.weatherError { Text(error).font(.caption).foregroundStyle(.secondary) }
            }
            Section(state.text("مواقيت الصلاة", "Prayer times")) {
                if let prayer=information.prayer,prayer.city==state.preferences.city,prayer.method==state.preferences.prayerMethod {
                    Text("\(prayer.city) · \(prayer.day) · \(prayer.timezone)").font(.caption)
                    ForEach(["Fajr","Sunrise","Dhuhr","Asr","Maghrib","Isha"],id:\.self) { name in HStack { Text(state.text(prayerNames[name] ?? name,name));Spacer();Text(prayer.timings[name] ?? "—").monospacedDigit() } }
                    TimelineView(.periodic(from:.now,by:1)) { context in if let next=information.nextPrayer(at:context.date) { HStack { Text(state.text("الصلاة التالية: ","Next prayer: ")+state.text(prayerNames[next.0] ?? next.0,next.0));Spacer();Text(next.1,style:.timer).monospacedDigit() } } }
                } else { Text(state.text("مواقيت الصلاة غير متاحة. اختر المدينة وطريقة الحساب في الإعدادات.", "Prayer times are unavailable. Choose a city and calculation method in Settings.")) }
                if let error=information.prayerError { Text(error).font(.caption).foregroundStyle(.secondary) }
                Link("AlAdhan · "+state.text("طريقة الحساب", "Calculation method"),destination:URL(string:"https://aladhan.com/calculation-methods")!)
                Text(state.text("مواقيت محسوبة للاستدلال؛ راجع مواقيت المسجد المحلي. طريقة دبي تجريبية.", "Calculated times are for reference; check your local mosque. The Dubai method is experimental.")).font(.caption).foregroundStyle(.secondary)
            }
            Section(state.text("الأذكار والمحتوى الموثّق", "Remembrance and sourced content")) {
                if state.religious.isEmpty { Text(state.text("لم يُنشر محتوى موثّق بعد.", "No sourced content has been published yet.")) }
                ForEach(state.religious) { item in VStack(alignment:.leading,spacing:10) { Text(state.text(item.title_ar,item.title_en)).font(.headline);Text(state.text(item.text_ar,item.text_en));if let source=WudDomain.validURL(item.source_url) { Link(item.source_title,destination:source).font(.caption) } }.padding(.vertical,6) }
            }
        }.navigationTitle(state.text("معلومات رحلتك", "Journey information"))
        .task(id:"\(state.preferences.city)-\(state.preferences.prayerMethod)") { await information.refresh(city:state.preferences.city,method:state.preferences.prayerMethod) }
        .refreshable { await information.refresh(city:state.preferences.city,method:state.preferences.prayerMethod) }
    }
}
