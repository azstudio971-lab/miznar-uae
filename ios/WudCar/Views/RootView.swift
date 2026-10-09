import SwiftUI
import AVKit

struct RootView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        TabView {
            NavigationStack { HomeView() }.tabItem { Label(state.text("الرئيسية", "Home"), systemImage: "house") }
            NavigationStack { ThemesView() }.tabItem { Label(state.text("الثيمات", "Themes"), systemImage: "sparkles") }
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
    @ObservedObject var cache=ThemeCache.shared
    var theme: Theme
    var forcedPeriod: String? = nil
    var editable=false
    private let identifiers=["clock","date","greeting","weather","prayer","adhkar","music"]
    var body:some View {
        TimelineView(.periodic(from:.now,by:1)) { context in
            GeometryReader { geometry in
                let layout=WudDomain.layout(width:geometry.size.width,height:geometry.size.height)
                let period=forcedPeriod ?? WudDomain.period(date:context.date,theme:theme)
                ZStack {
                    background(layout:layout,period:period,date:context.date)
                    LinearGradient(colors:[.black.opacity(0.55),.clear],startPoint:.topTrailing,endPoint:.bottomLeading)
                    ForEach(identifiers.sorted{theme.widget($0).sort_order<theme.widget($1).sort_order},id:\.self) { id in
                        let setting=theme.widget(id)
                        let custom=state.preferences.widgetOverrides[theme.id+":"+id]
                        if setting.visible && (setting.allow_hide ? (state.preferences.widgets[id] ?? true) && custom?.hidden != true : true) {
                            ThemeWidget(id:id,date:context.date,theme:theme)
                                .scaleEffect((setting.allow_resize ? custom?.scale ?? setting.scale : setting.scale)*state.preferences.widgetScale)
                                .opacity((custom?.opacity ?? setting.opacity)*state.preferences.widgetOpacity)
                                .position(x:geometry.size.width*(setting.allow_move ? (custom?.x ?? setting.x) : setting.x),y:geometry.size.height*(setting.allow_move ? (custom?.y ?? setting.y) : setting.y))
                                .gesture(DragGesture().onEnded { value in
                                    guard editable && setting.allow_move else{return}
                                    let x=min(0.95,max(0.05,(custom?.x ?? setting.x)+value.translation.width/geometry.size.width))
                                    let y=min(0.95,max(0.05,(custom?.y ?? setting.y)+value.translation.height/geometry.size.height))
                                    state.preferences.widgetOverrides[theme.id+":"+id]=WidgetCustomization(x:x,y:y,scale:custom?.scale ?? setting.scale,opacity:custom?.opacity ?? setting.opacity,hidden:false)
                                    Task { await state.sync() }
                                },including:editable && setting.allow_move ? .all : .none)
                        }
                    }
                }.frame(width:geometry.size.width,height:geometry.size.height).clipped()
            }
        }.clipShape(RoundedRectangle(cornerRadius:24)).task(id:"\(theme.id)-\(theme.version)") { await cache.prepare(theme:theme) }
    }
    @ViewBuilder private func background(layout:String,period:String,date:Date)->some View {
        if forcedPeriod==nil,let medium=theme.currentMedium(layout:layout,date:date),let url=WudDomain.validURL(medium.url) { remote(url: url,identifier:medium.id,kind:medium.kind,layout:layout,period:period) }
        else if let asset=theme.assets.first(where:{$0.layout==layout && $0.period==period}),let url=WudDomain.validURL(asset.url) { remote(url:url,identifier:asset.id,kind:asset.kind,layout:layout,period:period) }
        else { builtin(period:period,layout:layout) }
    }
    @ViewBuilder private func remote(url:URL,identifier:String,kind:String,layout:String,period:String)->some View {
        if kind=="video" { ZStack { builtin(period:period,layout:layout);SilentThemeVideo(url:url) } }
        else if let file=cache.cached(theme:theme,identifier:identifier),let image=UIImage(contentsOfFile:file.path) { Image(uiImage:image).resizable().scaledToFill() }
        else { AsyncImage(url:url) { image in image.resizable().scaledToFill() } placeholder: { builtin(period:period,layout:layout) } }
    }
    private func builtin(period:String,layout:String)->some View { Image("\(layout)-\(period)").resizable().scaledToFill() }
}
struct HomeView: View {
    @EnvironmentObject var state: AppState
    @ObservedObject private var meter = UsageMeter.shared
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image("BrandIcon").resizable().frame(width: 42, height: 42).clipShape(RoundedRectangle(cornerRadius: 12))
                Text(state.text("مرحباً", "Welcome") + (state.preferences.name.isEmpty ? " 👋" : "، " + state.preferences.name)).font(.largeTitle.bold())
                VStack(alignment: .leading, spacing: 14) {
                    Text(state.text("خطتك الحالية", "YOUR PLAN")).font(.caption)
                    Text(meter.status?.entitled == true ? state.text("اشتراك نشط", "Active subscription") : state.text("التجربة المجانية", "Free trial")).font(.title2.bold())
                    Text(state.text("٣٠ دقيقة من الاستخدام الفعلي", "30 minutes of actual use")).font(.subheadline)
                    if let status = meter.status { Text(state.text("المتبقي: ", "Remaining: ") + "\(Int(ceil(Double(status.remaining_seconds)/60))) " + state.text("دقيقة", "minutes")) }
                    NavigationLink(state.text("تفاصيل الاشتراك", "Subscription details")) { SubscriptionView() }.tint(.white)
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(.white).background(Color(red: 0.04, green: 0.30, blue: 0.36), in: RoundedRectangle(cornerRadius: 22))
                Text(state.text("آخر التحديثات", "Latest updates")).font(.title3.bold())
                ForEach(state.updates) { item in VStack(alignment: .leading, spacing: 10) {
                    Text(item.version).font(.caption).foregroundStyle(.secondary)
                    Text(state.text(item.title_ar, item.title_en)).font(.headline)
                    Text(state.text(item.body_ar, item.body_en)).font(.subheadline).foregroundStyle(.secondary)
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary, in: RoundedRectangle(cornerRadius: 16)) }
                NavigationLink { CarPreviewView() } label: { VStack(alignment: .leading) { Image("ultrawide-sunset").resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 18)); Label(state.text("معاينة شاشة السيارة", "Preview car display"), systemImage: "car.side") } }
            }.padding(22)
        }.navigationBarTitleDisplayMode(.inline).refreshable { await state.refresh() }.task { await meter.loadStatus() }
    }
}
struct CarPreviewView: View {
    @EnvironmentObject var state: AppState
    @State private var period = "morning"
    @State private var editing = false
    var body: some View {
        ScrollView { VStack(spacing: 20) {
            Toggle(state.text("تعديل مواضع الأدوات المسموح بها", "Move permitted widgets"),isOn:$editing)
            Picker(state.text("الوقت", "Time"), selection: $period) { Text(state.text("الفجر", "Dawn")).tag("dawn"); Text(state.text("الصباح", "Morning")).tag("morning"); Text(state.text("المغرب", "Sunset")).tag("sunset"); Text(state.text("الليل", "Night")).tag("night") }.pickerStyle(.segmented)
            ThemeCanvas(theme: state.theme, forcedPeriod: period,editable:editing).aspectRatio(3, contentMode: .fit)
            ThemeCanvas(theme: state.theme, forcedPeriod: period,editable:editing).aspectRatio(1.25, contentMode: .fit)
            NavigationLink { MediaView() } label: { Label(state.text("الترفيه", "Entertainment"), systemImage: "play.rectangle.fill") }.buttonStyle(.borderedProminent)
            Text(state.text("يتغير توزيع المعاينة تلقائيًا حسب نسبة العرض إلى الارتفاع.", "Preview layout adapts to the viewport aspect ratio.")).font(.caption)
        }.padding().modifier(MeteredPreview()) }.navigationTitle(state.text("معاينة الثيم", "Theme preview"))
    }
}
struct ThemesView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView { LazyVStack(spacing: 20) { ForEach(state.themes) { theme in VStack(alignment: .leading) {
            Group { if let path = theme.thumbnail_url, let url = WudDomain.validURL(path) { AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Image("ultrawide-sunset").resizable().scaledToFill() } } else { Image("ultrawide-sunset").resizable().scaledToFill() } }.frame(height: 180).clipped().clipShape(RoundedRectangle(cornerRadius: 18))
            Text(state.text(theme.description_ar ?? "", theme.description_en ?? "")).font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 10)
            HStack { Text(theme.name(state.preferences.language)).font(.headline); Spacer(); Button(state.preferences.themeID == theme.id ? state.text("محدد", "Selected") : state.text("اختيار", "Select")) { state.preferences.themeID = theme.id; Task { await state.sync() } }.buttonStyle(.bordered) }
        } }.padding() } }.navigationTitle(state.text("الثيمات", "Themes"))
    }
}
