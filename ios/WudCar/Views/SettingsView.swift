import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @ObservedObject var cloud = CloudClient.shared
    @State private var auth = false
    @State private var deleting = false
    @State private var busy = false
    var body: some View {
        Form {
            Section(state.text("شخصي", "Personal")) {
                TextField(state.text("اسم التحية — اختياري", "Greeting name — optional"), text: $state.preferences.name).onChange(of: state.preferences.name) { _, value in state.preferences.name = String(value.prefix(40)) }
                Picker(state.text("اللغة", "Language"), selection: $state.preferences.language) { Text("العربية").tag("ar"); Text("English").tag("en") }
                Picker(state.text("المدينة", "City"), selection: $state.preferences.city) { ForEach(City.all) { city in Text(state.preferences.language == "ar" ? city.arabic : city.name).tag(city.name) } }
            }
            Section(state.text("معاينة الثيم على الهاتف", "Phone theme preview")) {
                ForEach(["clock", "date", "greeting"], id: \.self) { key in Toggle(widgetName(key), isOn: Binding(get: { state.preferences.widgets[key] ?? true }, set: { state.preferences.widgets[key] = $0 })) }
                Text(state.text("حجم النص", "Text scale")); Slider(value: $state.preferences.widgetScale, in: 0.8...1.3)
                Text(state.text("الوضوح", "Opacity")); Slider(value: $state.preferences.widgetOpacity, in: 0.5...1)
            }
            Section(state.text("الحساب", "Account")) {
                if let session = cloud.session {
                    Text(session.user.email ?? ""); Button(state.text("مزامنة إعداداتي", "Sync my preferences")) { Task { await state.sync() } }
                    Button(state.text("تسجيل الخروج", "Sign out")) { Task { await cloud.signOut(); state.messages = [] } }
                    Button(state.text("حذف الحساب نهائيًا", "Permanently delete account"), role: .destructive) { deleting = true }.disabled(busy)
                } else { Text(state.text("تستخدم التطبيق كضيف", "You are using guest mode")); Button(state.text("تسجيل الدخول أو إنشاء حساب", "Sign in or create an account")) { auth = true }.disabled(!AppConfiguration.configured)
                    if !AppConfiguration.configured { Text(state.text("الخدمة السحابية لم تُفعّل لهذه النسخة بعد.", "Cloud service is not configured in this build.")).font(.caption) }
                }
            }
            Section(state.text("الاشتراك", "Subscription")) { Text(state.text("الاشتراكات غير مفعّلة في هذه النسخة. ستظهر الأسعار وشروط التجربة من Apple عند إتاحة الشراء.", "Subscriptions are not enabled in this build. Apple pricing and trial terms will be shown when purchases become available.")); Link(state.text("إدارة اشتراكات Apple", "Manage Apple subscriptions"), destination: URL(string: "https://apps.apple.com/account/subscriptions")!) }
            Section { NavigationLink(state.text("الخصوصية", "Privacy")) { PolicyView(kind: "privacy") }; NavigationLink(state.text("الشروط والأحكام", "Terms")) { PolicyView(kind: "terms") }; NavigationLink(state.text("حذف الحساب", "Account deletion")) { PolicyView(kind: "delete") }; Link(state.text("تواصل معنا", "Contact support"), destination: URL(string: "mailto:az.studio971@gmail.com")!) }
            Section { Text("WudCar 0.1 · Rashed Saeed").font(.caption); Text(state.text("CarPlay: طلبا Audio وVideo بانتظار الموافقة. تشغيل الفيديو في السيارة مرتبط بدعم السيارة وقيود Apple.", "CarPlay: Audio and Video entitlement requests are pending. In-car video depends on vehicle support and Apple restrictions.")).font(.caption) }
        }.navigationTitle(state.text("الإعدادات", "Settings"))
        .sheet(isPresented: $auth) { AuthView() }
        .confirmationDialog(state.text("حذف الحساب والبيانات المرتبطة به؟ الاشتراك لدى Apple لا يُلغى تلقائيًا.", "Delete your account and associated data? Apple subscriptions are not automatically canceled."), isPresented: $deleting, titleVisibility: .visible) {
            Button(state.text("حذف نهائي", "Delete permanently"), role: .destructive) { busy = true; Task { defer { busy = false }; do { try await cloud.deleteAccount(); state.clearPersonalData() } catch { state.notice = error.localizedDescription } } }
        }
    }
    private func widgetName(_ key: String) -> String { switch key { case "clock": return state.text("الساعة", "Clock"); case "date": return state.text("التاريخ", "Date"); default: return state.text("التحية", "Greeting") } }
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
            Button(state.text("تسجيل الدخول", "Sign in")) { run { try await CloudClient.shared.signIn(email: email, password: password); if let preferences = try await CloudClient.shared.profile() { state.preferences = preferences } else { await state.sync() }; await state.refresh(); dismiss() } }.disabled(busy || email.isEmpty || password.isEmpty)
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
        let policy = Self.load(kind, language: state.preferences.language)
        ScrollView { VStack(alignment: .leading, spacing: 18) { Text(policy.title).font(.largeTitle.bold()); ForEach(Array(policy.sections.enumerated()), id: \.offset) { _, section in VStack(alignment: .leading, spacing: 8) { Text(section[0]).font(.headline); Text(section[1]) } } }.padding() }.navigationTitle(policy.title)
    }
    struct Policy: Decodable { let title: String; let sections: [[String]] }
    static func load(_ kind: String, language: String) -> Policy {
        guard let url = Bundle.main.url(forResource: "policies", withExtension: "json"), let data = try? Data(contentsOf: url), let all = try? JSONDecoder().decode([String: [String: Policy]].self, from: data), let policy = all[kind]?[language] else { return Policy(title: "WudCar", sections: [["Support", "az.studio971@gmail.com"]]) }; return policy
    }
}
