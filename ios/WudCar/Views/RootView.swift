import SwiftUI
import AVKit

struct RootView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        TabView {
            NavigationStack { HomeView() }.tabItem { Label(state.text("الرئيسية", "Home"), systemImage: "house") }
            NavigationStack { ThemesView() }.tabItem { Label(state.text("الثيمات", "Themes"), systemImage: "sparkles") }
            NavigationStack { InformationView() }.tabItem { Label(state.text("المعلومات", "Information"), systemImage: "sun.max") }
            NavigationStack { MediaView() }.tabItem { Label(state.text("مكتبتي", "Library"), systemImage: "play.rectangle") }
            NavigationStack { SettingsView() }.tabItem { Label(state.text("الإعدادات", "Settings"), systemImage: "slider.horizontal.3") }
        }
        .sheet(isPresented: Binding(get: { !state.preferences.onboarded }, set: { if !$0 { state.preferences.onboarded = true } })) { WelcomeView().interactiveDismissDisabled() }
        .alert(state.text("تنبيه", "Notice"), isPresented: Binding(get: { state.notice != nil }, set: { if !$0 { state.notice = nil } })) { Button(state.text("حسنًا", "OK")) { state.notice = nil } } message: { Text(state.notice ?? "") }
    }
}
struct WelcomeView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        VStack(spacing: 24) {
            Image("BrandIcon").resizable().scaledToFit().frame(width: 100, height: 100).clipShape(RoundedRectangle(cornerRadius: 24))
            Text("WudCar").font(.largeTitle.bold()); Text(state.text("رفيق مشاويرك", "Your journey companion")).font(.title2)
            Picker("Language", selection: $state.preferences.language) { Text("العربية").tag("ar"); Text("English").tag("en") }.pickerStyle(.segmented)
            TextField(state.text("ما الاسم الذي تحب أن نناديك به؟", "What name would you like us to use?"), text: $state.preferences.name).textFieldStyle(.roundedBorder).onChange(of: state.preferences.name) { _, value in state.preferences.name = String(value.prefix(40)) }
            Text(state.text("ابدأ كضيف. تحتاج بعض الخدمات إلى الإنترنت. اعتمد على الطريق أثناء القيادة؛ واجهة CarPlay تخضع لما تسمح به Apple وسيارتك.", "Start as a guest. Some services require internet. Keep your attention on the road; CarPlay features depend on Apple approval and your vehicle.")).font(.callout).foregroundStyle(.secondary)
            Button(state.text("ابدأ رحلتك", "Start your journey")) { state.preferences.onboarded = true }.buttonStyle(.borderedProminent)
        }.padding(28)
    }
}
struct ThemeCanvas: View {
    @EnvironmentObject var state: AppState
    var theme: Theme
    var forcedPeriod: String? = nil
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            GeometryReader { geometry in
                let layout = WudDomain.layout(width: geometry.size.width, height: geometry.size.height)
                let period = forcedPeriod ?? WudDomain.period(date: context.date, theme: theme)
                ZStack(alignment: .topTrailing) {
                    if let asset = theme.assets.first(where: { $0.layout == layout && $0.period == period && $0.kind == "image" }), let url = URL(string: asset.url) {
                        AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { builtin(period: period, layout: layout) }
                    } else { builtin(period: period, layout: layout) }
                    LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .topTrailing, endPoint: .bottomLeading)
                    VStack(alignment: .trailing, spacing: 5) {
                        if state.preferences.widgets["clock"] == true && theme.widgets["clock"] != false { Text(context.date, style: .time).font(.system(size: 34, weight: .light, design: .rounded)) }
                        if state.preferences.widgets["date"] == true && theme.widgets["date"] != false { Text(context.date, style: .date).font(.caption) }
                        if state.preferences.widgets["greeting"] == true && theme.widgets["greeting"] != false { Text(WudDomain.greeting(name: state.preferences.name, hour: Calendar.current.component(.hour, from: context.date), language: state.preferences.language)).font(.callout) }
                    }.foregroundStyle(.white).padding(22).opacity(state.preferences.widgetOpacity).scaleEffect(state.preferences.widgetScale, anchor: .topTrailing)
                }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
            }
        }.clipShape(RoundedRectangle(cornerRadius: 24))
    }
    private func builtin(period: String, layout: String) -> some View { Image("\(layout)-\(period)").resizable().scaledToFill() }
}
struct HomeView: View {
    @EnvironmentObject var state: AppState
    @ObservedObject var player = PlayerService.shared
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(state.text("رفيق مشاويرك", "Your journey companion")).font(.title.bold())
                ThemeCanvas(theme: state.theme).frame(height: 290)
                HStack { Label(state.preferences.city, systemImage: "location"); Spacer(); Text(state.theme.name(state.preferences.language)).font(.caption) }.foregroundStyle(.secondary)
                NavigationLink { CarPreviewView() } label: { Label(state.text("معاينة روح الإمارات", "Preview Spirit of the UAE"), systemImage: "car.side") }.buttonStyle(.bordered)
                Text(state.text("هذه معاينة تصميم داخل الهاتف. تعرض CarPlay قوالب Apple المعتمدة، ولا تستبدل خلفية نظام السيارة.", "This is an in-phone design preview. CarPlay uses approved Apple templates and does not replace your car’s system wallpaper.")).font(.caption).foregroundStyle(.secondary)
                if !player.title.isEmpty { VStack { Text(player.title).font(.headline); VideoPlayer(player: player.player).frame(height: 210); AirPlayButton().frame(width: 44, height: 44); Button(state.text("إيقاف", "Stop")) { player.stop() } } }
                if let error = player.error { Text(error).foregroundStyle(.red) }
                if !state.messages.isEmpty { Text(state.text("رسائلك", "Your messages")).font(.headline); ForEach(state.messages) { item in VStack(alignment: .leading) { Text(state.preferences.language == "ar" ? item.title_ar : item.title_en).bold(); Text(state.preferences.language == "ar" ? item.body_ar : item.body_en) }.padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 14)) } }
            }.padding()
        }.navigationTitle("WudCar").refreshable { await state.refresh() }
    }
}
struct CarPreviewView: View {
    @EnvironmentObject var state: AppState
    @State private var period = "morning"
    var body: some View {
        ScrollView { VStack(spacing: 20) {
            Picker(state.text("الوقت", "Time"), selection: $period) { Text(state.text("الفجر", "Dawn")).tag("dawn"); Text(state.text("الصباح", "Morning")).tag("morning"); Text(state.text("المغرب", "Sunset")).tag("sunset"); Text(state.text("الليل", "Night")).tag("night") }.pickerStyle(.segmented)
            ThemeCanvas(theme: state.theme, forcedPeriod: period).aspectRatio(3, contentMode: .fit)
            ThemeCanvas(theme: state.theme, forcedPeriod: period).aspectRatio(1.25, contentMode: .fit)
            Text(state.text("يتغير توزيع المعاينة تلقائيًا حسب نسبة العرض إلى الارتفاع.", "Preview layout adapts to the viewport aspect ratio.")).font(.caption)
        }.padding() }.navigationTitle(state.text("معاينة الثيم", "Theme preview"))
    }
}
struct ThemesView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView { LazyVStack(spacing: 20) { ForEach(state.themes) { theme in VStack(alignment: .leading) {
            ThemeCanvas(theme: theme).frame(height: 210)
            HStack { Text(theme.name(state.preferences.language)).font(.headline); Spacer(); Button(state.preferences.themeID == theme.id ? state.text("محدد", "Selected") : state.text("اختيار", "Select")) { state.preferences.themeID = theme.id; Task { await state.sync() } }.buttonStyle(.bordered) }
        } }.padding() } }.navigationTitle(state.text("الثيمات", "Themes"))
    }
}
