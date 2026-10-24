import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var managing = false

    private var trialAvailable: Bool {
        store.eligibleForTrial && store.product?.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "crown.fill").font(.system(size: 42)).foregroundStyle(Color.wdNavy)
                Text(tr("اشتراك ود كار", "WudCar Premium")).font(.title.bold())
                Text(tr("المكتبة ومشغّل الويب والترفيه وM3U IPTV Player والتحكم بالماوس.",
                        "Library, Web Player, entertainment, M3U IPTV Player and mouse control."))
                    .multilineTextAlignment(.center)
                VStack(spacing: 10) {
                    LabeledContent(tr("حالة الاشتراك", "Subscription status"), value: store.state.title)
                    if let date = store.validUntil {
                        LabeledContent(dateLabel) { Text(date, format: .dateTime.day().month().year().hour().minute()) }
                    }
                    if store.hasAccess, store.willAutoRenew == false {
                        Text(tr("التجديد التلقائي مُلغى. تظل المزايا متاحة حتى تاريخ الانتهاء.",
                                "Auto-renewal is off. Access continues until the expiration date."))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding().background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                if !store.hasAccess {
                    if let product = store.product {
                        Text(trialAvailable
                             ? tr("3 أيام مجاناً، ثم \(product.displayPrice) شهرياً", "3 days free, then \(product.displayPrice) per month")
                             : tr("\(product.displayPrice) شهرياً", "\(product.displayPrice) per month"))
                            .font(.title3.bold()).accessibilityIdentifier("subscription.price")
                        Text(trialAvailable
                             ? tr("للمؤهلين فقط. تبدأ التجربة بعد تأكيد الاشتراك لدى أبل. يتجدد الاشتراك تلقائياً بالسعر الشهري المعروض ما لم تُلغِه من إعدادات اشتراكات أبل قبل التجديد. لا يتضمن الاشتراك محتوى أو حسابات IPTV.",
                                  "Eligible customers only. The trial starts when you confirm with Apple. The subscription automatically renews at the displayed monthly price unless cancelled in Apple subscription settings before renewal. IPTV content and accounts are not included.")
                             : tr("اشتراك شهري متجدد تلقائياً. السعر المعروض من متجر أبل الخاص بك. يمكنك إلغاء التجديد من إعدادات اشتراكات أبل. لا يتضمن الاشتراك محتوى أو حسابات IPTV.",
                                  "Monthly auto-renewing subscription. The displayed price is from your Apple storefront. Cancel renewal in Apple subscription settings. IPTV content and accounts are not included."))
                            .font(.footnote).foregroundStyle(.secondary)
                        Button { Task { await store.purchase() } } label: {
                            Text(trialAvailable ? tr("ابدأ التجربة المجانية", "Start free trial") : tr("اشترك شهرياً", "Subscribe monthly"))
                                .frame(maxWidth: .infinity).padding(8)
                        }.buttonStyle(.borderedProminent).disabled(store.busy)
                    } else {
                        Text(tr("الاشتراك غير متاح للشراء حالياً. تحقق من الاتصال أو حاول لاحقاً.",
                                "The subscription is not currently available for purchase. Check your connection or retry later."))
                        Button(tr("إعادة المحاولة", "Retry")) { Task { await store.refresh() } }
                    }
                }
                Text(tr("يتجدد الاشتراك تلقائياً. ألغِه قبل 24 ساعة على الأقل من نهاية الفترة من إعدادات حساب Apple. حذف التطبيق لا يلغي الاشتراك.", "Auto-renews unless cancelled at least 24 hours before the period ends in Apple Account settings. Deleting the app does not cancel it.")).font(.footnote)
                NavigationLink(tr("شروط الاستخدام", "Terms of Use")) { LegalTextView(kind: .terms) }
                NavigationLink(tr("شروط الاشتراك", "Subscription terms")) { LegalTextView(kind: .subscription) }
                if store.busy { ProgressView() }
                if let message = store.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                Button(tr("إدارة الاشتراك", "Manage subscription")) { managing = true }
                Button(tr("استعادة المشتريات", "Restore purchases")) { Task { await store.restore() } }.disabled(store.busy)
                HStack {
                    NavigationLink(tr("الخصوصية", "Privacy")) { LegalTextView(kind: .privacy) }
                    Spacer()
                    Link(tr("شروط الاشتراك", "Subscription terms"), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                }.font(.footnote)
            }.padding(24)
        }
        .navigationTitle(tr("حالة الاشتراك", "Subscription status"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("subscription.screen")
        .manageSubscriptionsSheet(isPresented: $managing)
        .task { await store.refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.refresh() } } }
    }

    private var dateLabel: String {
        if store.state == .trial { return tr("تنتهي التجربة", "Trial ends") }
        if store.hasAccess && store.willAutoRenew == true { return tr("موعد التجديد", "Renews") }
        return tr("تاريخ الانتهاء", "Expires")
    }
}

struct SubscriptionGate<Content: View>: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ViewBuilder let content: () -> Content
    var body: some View {
        if store.hasAccess { content() }
        else { NavigationStack { SubscriptionView() } }
    }
}
