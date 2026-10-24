import SwiftUI

struct HomeView: View {
    let selectTab: (Int) -> Void
    @EnvironmentObject private var app: AppState
    @Environment(\.colorScheme) private var scheme
    @ObservedObject private var shortcuts = ShortcutStore.shared
    @State private var entertainment = false
    @ObservedObject private var m3u = M3UStore.shared
    @ObservedObject private var library = MediaLibrary.shared
    @ObservedObject private var xtream = XtreamStore.shared

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? tr("صباح الخير 👋", "Good morning 👋") : tr("مساء الخير 👋", "Good evening 👋")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    logo
                        .padding(.top, 8)

                    VStack(spacing: 6) {
                        Text(greeting).font(.title2.bold())
                        Text(tr("رفيق مشاويرك", "Your road companion"))
                            .foregroundStyle(.secondary)
                    }

                    carStatus

                    HomeCard(symbol: "play.rectangle.on.rectangle", title: tr("المكتبة", "Library"), subtitle: tr("الفيديو والصوت وقوائم التشغيل", "Video, audio and playlists")) { selectTab(1) }
                    HomeCard(symbol: "antenna.radiowaves.left.and.right", title: "M3U IPTV Player", subtitle: tr("\(m3u.playlists.count) قائمة • \(xtream.accounts.count) حساب", "\(m3u.playlists.count) playlists • \(xtream.accounts.count) accounts")) { selectTab(2) }
                    HomeCard(symbol: "play.tv", title: tr("الترفيه", "Entertainment"), subtitle: tr("\(shortcuts.shortcuts.count) موقع في الاختصارات", "\(shortcuts.shortcuts.count) saved sites")) { entertainment = true }
                    HomeCard(symbol: "gearshape",
                             title: tr("الإعدادات", "Settings"),
                             subtitle: tr("اللغة، وضع العرض، البيانات", "Language, appearance, data")) {
                        selectTab(3)
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $entertainment) { SubscriptionGate { PhoneBrowserScreen() } }
        }
    }

    @ViewBuilder
    private var logo: some View {
        if scheme == .dark {
            VStack(spacing: 10) {
                Image("LogoMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .overlay { SeasonalLogoOverlay() }
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                Text("WudCar").font(.system(size: 34, weight: .heavy))
                Text("وُد كار").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
            }
        } else {
            Image("LogoDay")
                .resizable()
                .aspectRatio(1145.0 / 1373.0, contentMode: .fit)
                .frame(width: 220)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 12)
                .accessibilityIdentifier("home.logo.day")
        }
    }

    private var carStatus: some View {
        HStack(spacing: 12) {
            Image(systemName: app.isCarConnected ? "car.fill" : "car")
                .font(.title2)
                .foregroundStyle(app.isCarConnected ? Color.wdAccent : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("CarPlay").font(.headline)
                HStack {
                    Circle().fill(app.isCarConnected ? Color.green : Color(.systemGray)).frame(width: 8, height: 8)
                    Text(app.isCarConnected ? tr("متصل", "Connected") : tr("غير متصل", "Not connected"))
                        .foregroundStyle(app.isCarConnected ? Color.green : Color(.systemGray))
                }.font(.subheadline)

            }
            Spacer()
            if app.isCarConnected || app.carScreenActive {
                Button { app.showCarScreenHelp = true } label: {
                    Image(systemName: "safari")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Color.wdNavy))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemBackground)))
    }
}

private struct HomeCard: View {
    let symbol: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.wdNavy))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.forward").foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
    }
}
