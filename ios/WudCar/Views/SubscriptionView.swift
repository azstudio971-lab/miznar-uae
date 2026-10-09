import SwiftUI
import StoreKit

struct SubscriptionView:View {
    @EnvironmentObject var state:AppState
    @StateObject private var store=SubscriptionStore()
    var body:some View {
        List {
            Section { Text(state.text("رفيق مشاويرك", "Your journey companion")).font(.title2.bold());Text(state.text("الثيمات والأدوات والوسائط المدعومة حسب الخطة المتاحة.", "Themes, widgets and supported media according to the available plan.")) }
            if !AppConfiguration.subscriptionsEnabled {
                Section { Text(state.text("الشراء والتجربة المدفوعة غير مفعّلين في نسخة التطوير. لن يُخصم أي مبلغ.", "Purchases and metered evaluation are disabled in this development build. No charge will be made.")) }
            } else {
                Section(state.text("خطط Apple", "Apple plans")) {
                    if store.products.isEmpty { Text(state.text("لا توجد منتجات متاحة؛ أعد المحاولة لاحقًا.", "No products are available; try again later.")) }
                    ForEach(store.products,id:\.id) { product in VStack(alignment:.leading,spacing:10) {
                        Text(product.displayName).font(.headline);Text(product.description);Text(product.displayPrice).font(.title2)
                        if let subscription=product.subscription { Text(period(subscription.subscriptionPeriod)).font(.caption) }
                        Button(state.text("متابعة مع Apple", "Continue with Apple")) { Task { await store.buy(product) } }.disabled(CloudClient.shared.session==nil)
                    }.padding(.vertical,6) }
                    if CloudClient.shared.session==nil { Text(state.text("سجّل الدخول لربط الاستحقاق بحسابك.", "Sign in to associate access with your account.")) }
                    Text(state.text("يعرض تأكيد Apple السعر والمدة وشروط العرض والتجديد النهائية. يتجدد الاشتراك وفق شروط Apple ما لم تلغه.", "Apple confirmation shows the final price, duration, offer and renewal terms. Subscriptions renew under Apple’s terms unless canceled.")).font(.caption)
                }
                Section { Button(state.text("استعادة المشتريات", "Restore purchases")) { Task { await store.restore() } };Text(store.entitled ? state.text("لديك استحقاق موثّق على هذا الجهاز", "Verified device entitlement is active") : state.text("لا يوجد استحقاق فعّال على هذا الجهاز", "No active device entitlement")) }
            }
            if let message=store.message { Section { Text(message).foregroundStyle(.secondary) } }
            Section { Link(state.text("إدارة اشتراكات Apple", "Manage Apple subscriptions"),destination:URL(string:"https://apps.apple.com/account/subscriptions")!);NavigationLink(state.text("شروط الاشتراك", "Subscription terms")) { PolicyView(kind:"subscription") };NavigationLink(state.text("الخصوصية", "Privacy")) { PolicyView(kind:"privacy") };NavigationLink(state.text("الترخيص", "License")) { PolicyView(kind:"eula") };NavigationLink(state.text("الاسترداد", "Refunds")) { PolicyView(kind:"refund") } }
        }.navigationTitle(state.text("الاشتراك", "Subscription")).task { await store.load() }
    }
    private func period(_ period:Product.SubscriptionPeriod)->String {
        let unit:String
        switch period.unit {case .day:unit=state.text("يوم", "day");case .week:unit=state.text("أسبوع", "week");case .month:unit=state.text("شهر", "month");case .year:unit=state.text("سنة", "year");@unknown default:unit="—"}
        return state.text("يتجدد كل ", "Renews every ")+"\(period.value) \(unit)"
    }
}
