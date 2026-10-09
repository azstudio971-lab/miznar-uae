import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @ObservedObject private var location = LocationService.shared
    @ObservedObject private var push = PushService.shared
    @ObservedObject var cloud = CloudClient.shared
    @State private var auth = false
    @State private var deleting = false
    @State private var busy = false
    @State private var clearLocal = false
    var body: some View {
        Form {
            Section(state.text("شخصي", "Personal")) {
                TextField(state.text("اسم التحية — اختياري", "Greeting name — optional"), text: $state.preferences.name).onChange(of: state.preferences.name) { _, value in state.preferences.name = String(value.prefix(40)) }
                Picker(state.text("اللغة", "Language"), selection: $state.preferences.language) { Text("العربية").tag("ar"); Text("English").tag("en") }
                Button { location.request() } label: { Label(state.text("استخدام موقعي الحالي", "Use my location"), systemImage: "location.fill") }.disabled(location.locating)
                if let error = location.error { Text(error).font(.caption).foregroundStyle(.secondary) }
                Text(state.preferences.timezone).font(.caption).foregroundStyle(.secondary)
                Picker(state.text("المدينة", "City"), selection: $state.preferences.city) { ForEach(City.all) { city in Text(state.preferences.language == "ar" ? city.arabic : city.name).tag(city.name) } }
            }
            Section(state.text("المظهر والمواقيت", "Appearance and prayer times")) {
                Picker(state.text("المظهر", "Appearance"),selection:$state.preferences.appearance) { Text(state.text("تلقائي", "System")).tag("system");Text(state.text("فاتح", "Light")).tag("light");Text(state.text("داكن", "Dark")).tag("dark") }
                Picker(state.text("شكل الساعة", "Clock style"),selection:$state.preferences.clockStyle) { Text(state.text("رقمية", "Digital")).tag("digital");Text(state.text("عقارب", "Analog")).tag("analog") }
                Toggle(state.text("نظام 24 ساعة", "24-hour clock"),isOn:$state.preferences.uses24HourClock)
                Toggle(state.text("التاريخ الهجري", "Hijri date"),isOn:$state.preferences.showHijri)
                Picker(state.text("طريقة حساب الصلاة", "Prayer calculation method"),selection:$state.preferences.prayerMethod) { Text(state.text("الخليج", "Gulf")).tag(8);Text("Muslim World League").tag(3);Text("Umm Al-Qura").tag(4);Text(state.text("دبي — تجريبية", "Dubai — experimental")).tag(16) }
            }
            Section(state.text("معاينة الثيم على الهاتف", "Phone theme preview")) {
                NavigationLink(state.text("تخصيص أدوات الثيم", "Customize theme widgets")) { WidgetSettingsView() }
                ForEach(["prayer", "music", "clock", "weather", "adhkar", "date", "greeting"], id: \.self) { key in Toggle(widgetName(key), isOn: Binding(get: { state.preferences.widgets[key] ?? true }, set: { state.preferences.widgets[key] = $0; if key == "music" { state.preferences.musicEnabled = $0 } })) }
                Text(state.text("حجم النص", "Text scale")); Slider(value: $state.preferences.widgetScale, in: 0.8...1.3)
                Text(state.text("الوضوح", "Opacity")); Slider(value: $state.preferences.widgetOpacity, in: 0.5...1)
            }
            Section(state.text("الإشعارات", "Notifications")) {
                Button(state.text("تفعيل إشعارات منطقتي", "Enable regional notifications")) { Task { await push.requestPermission() } }
                if !push.status.isEmpty { Text(push.status).font(.caption) }
            }
            Section(state.text("الحساب", "Account")) {
                if let session = cloud.session {
                    Text(session.user.email ?? ""); NavigationLink(state.text("الأجهزة والجلسات", "Devices and sessions")) { DevicesView() }; Button(state.text("مزامنة إعداداتي", "Sync my preferences")) { Task { await state.sync() } }
                    Button(state.text("تسجيل الخروج", "Sign out")) { Task { await cloud.signOut(); state.messages = [] } }
                    Button(state.text("حذف الحساب نهائيًا", "Permanently delete account"), role: .destructive) { deleting = true }.disabled(busy)
                } else { Text(state.text("تستخدم التطبيق كضيف", "You are using guest mode")); Button(state.text("تسجيل الدخول أو إنشاء حساب", "Sign in or create an account")) { auth = true }.disabled(!AppConfiguration.configured)
                    if !AppConfiguration.configured { Text(state.text("الخدمة السحابية لم تُفعّل لهذه النسخة بعد.", "Cloud service is not configured in this build.")).font(.caption) }
                }
            }
            Section(state.text("الاشتراك", "Subscription")) { NavigationLink(state.text("الخطة والمشتريات", "Plans and purchases")) { SubscriptionView() }; Text(state.text("الاشتراكات غير مفعّلة في هذه النسخة. ستظهر الأسعار وشروط التجربة من Apple عند إتاحة الشراء.", "Subscriptions are not enabled in this build. Apple pricing and trial terms will be shown when purchases become available.")); Link(state.text("إدارة اشتراكات Apple", "Manage Apple subscriptions"), destination: URL(string: "https://apps.apple.com/account/subscriptions")!) }
            Section { NavigationLink(state.text("الخصوصية", "Privacy")) { PolicyView(kind: "privacy") }; NavigationLink(state.text("الشروط والأحكام", "Terms")) { PolicyView(kind: "terms") }; NavigationLink(state.text("حذف الحساب", "Account deletion")) { PolicyView(kind: "delete") }; ForEach(["eula","subscription","refund","retention"],id:\.self) { kind in NavigationLink(PolicyView.load(kind,language:state.preferences.language).title) { PolicyView(kind:kind) } }; Link(state.text("تواصل معنا", "Contact support"), destination: URL(string: "mailto:az.studio971@gmail.com")!) }
            Section { Button(state.text("مسح البيانات المحلية", "Clear local data"), role: .destructive) { clearLocal = true } }
            Section { Text("WudCar 1.1.1 · Rashed Saeed").font(.caption); Text(state.text("CarPlay: طلبا Audio وVideo بانتظار الموافقة. تشغيل الفيديو في السيارة مرتبط بدعم السيارة وقيود Apple.", "CarPlay: Audio and Video entitlement requests are pending. In-car video depends on vehicle support and Apple restrictions.")).font(.caption) }
        }.navigationTitle(state.text("الإعدادات", "Settings"))
        .onChange(of: state.preferences.city) { _, city in if let selected = City.all.first(where: { $0.name == city }) { state.preferences.locationMode = "manual"; state.preferences.latitude = selected.lat; state.preferences.longitude = selected.lon; state.preferences.region = city == "Dibba" ? "Fujairah" : city; state.preferences.timezone = "Asia/Dubai"; Task { await state.refresh() } } }
        .onDisappear { Task { await state.sync() } }
        .sheet(isPresented: $auth) { AuthView() }
        .confirmationDialog(state.text("مسح التفضيلات والوسائط المحلية؟ يبقى حسابك السحابي قائمًا.", "Clear local preferences and media? Your cloud account will remain."), isPresented: $clearLocal, titleVisibility: .visible) {
            Button(state.text("مسح وتسجيل الخروج", "Clear and sign out"), role: .destructive) { Task { await cloud.signOut(); state.clearPersonalData() } }
        }
        .confirmationDialog(state.text("حذف الحساب والبيانات المرتبطة به؟ الاشتراك لدى Apple لا يُلغى تلقائيًا.", "Delete your account and associated data? Apple subscriptions are not automatically canceled."), isPresented: $deleting, titleVisibility: .visible) {
            Button(state.text("حذف نهائي", "Delete permanently"), role: .destructive) { busy = true; Task { defer { busy = false }; do { try await cloud.deleteAccount(); state.clearPersonalData() } catch { state.notice = error.localizedDescription } } }
        }
    }
    private func widgetName(_ key: String) -> String { switch key { case "prayer": return state.text("أوقات الصلاة", "Prayer times"); case "music": return state.text("مشغل الموسيقى", "Music player"); case "weather": return state.text("حالة الطقس", "Weather"); case "adhkar": return state.text("الأذكار", "Adhkar"); case "clock": return state.text("الساعة", "Clock"); case "date": return state.text("التاريخ", "Date"); default: return state.text("التحية", "Greeting") } }
}
struct AuthView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var feedback = ""
    var body: some View {
        NavigationStack { Form {
            TextField(state.text("البريد الإلكتروني", "Email"), text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
            SecureField(state.text("كلمة المرور", "Password"), text: $password).textContentType(.password)
            if !feedback.isEmpty { Text(feedback).font(.callout) }
            if busy { ProgressView() }
            Button(state.text("تسجيل الدخول", "Sign in")) { run { try await CloudClient.shared.signIn(email: email, password: password); if let preferences = try await CloudClient.shared.profile() { state.preferences = preferences } else { await state.sync() }; try await CloudClient.shared.loadLibrary(); await state.refresh(); dismiss() } }.disabled(busy || email.isEmpty || password.isEmpty)
            Button(state.text("إنشاء حساب", "Create account")) { run { try await CloudClient.shared.signUp(email: email, password: password); feedback = state.text("راجع بريدك لتأكيد الحساب ثم سجّل الدخول.", "Check your email to confirm your account, then sign in.") } }.disabled(busy || email.isEmpty || password.count < 8)
            Button(state.text("نسيت كلمة المرور", "Forgot password")) { run { try await CloudClient.shared.recover(email: email); feedback = state.text("إذا كان الحساب موجودًا، سيصلك رابط الاستعادة.", "If an account exists, a recovery link will be sent.") } }.disabled(busy || email.isEmpty)
        }.navigationTitle(state.text("حساب WudCar", "WudCar account")).toolbar { Button(state.text("إغلاق", "Close")) { dismiss() } } }
    }
    private func run(_ action: @escaping @MainActor () async throws -> Void) { busy = true; feedback = ""; Task { defer { busy = false }; do { try await action() } catch { feedback = error.localizedDescription } } }
}
struct PolicyView: View {
    @EnvironmentObject var state: AppState
    let kind: String
    var body: some View {
        let remote=state.legal.first{$0.id==kind}
        let policy=remote.map{ Policy(title:state.text($0.title_ar,$0.title_en),sections:(state.preferences.language=="ar" ? $0.sections_ar : $0.sections_en).filter{$0.count==2}) } ?? Self.load(kind, language: state.preferences.language)
        ScrollView { VStack(alignment: .leading, spacing: 18) { Text(policy.title).font(.largeTitle.bold()); ForEach(Array(policy.sections.enumerated()), id: \.offset) { _, section in VStack(alignment: .leading, spacing: 8) { Text(section[0]).font(.headline); Text(section[1]) } } }.padding() }.navigationTitle(policy.title)
    }
    struct Policy: Decodable { let title: String; let sections: [[String]] }
    static func load(_ kind: String, language: String) -> Policy {
        guard let url = Bundle.main.url(forResource: "policies", withExtension: "json"), let data = try? Data(contentsOf: url), let all = try? JSONDecoder().decode([String: [String: Policy]].self, from: data), let policy = all[kind]?[language] else { return Policy(title: "WudCar", sections: [["Support", "az.studio971@gmail.com"]]) }; return policy
    }
}
