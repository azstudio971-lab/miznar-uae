import SwiftUI

struct HomeView: View {
    let selectTab: (Int) -> Void
    @EnvironmentObject private var app: AppState
    @Environment(\.colorScheme) private var scheme
    @ObservedObject private var shortcuts = ShortcutStore.shared
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

                    HomeCard(symbol: "cursorarrow.rays",
                             title: tr("الماوس", "Mouse"),
                             subtitle: tr("الماوس يعمل بالمتصفح فقط أثناء توقف السيارة.",
                                          "Mouse works in the browser only while the car is stopped.")) {
                        selectTab(3)
                    }

                    HomeCard(symbol: "play.tv",
                             title: tr("الترفيه", "Entertainment"),
                             subtitle: tr("\(shortcuts.shortcuts.count) موقع في الاختصارات", "\(shortcuts.shortcuts.count) saved sites")) {
                        selectTab(1)
                    }
                    HomeCard(symbol: "antenna.radiowaves.left.and.right",
                             title: "Xtream Codes",
                             subtitle: xtream.accounts.isEmpty
                                ? tr("أضف حسابك لمشاهدة القنوات", "Add your account to watch channels")
                                : tr("\(xtream.accounts.count) حساب", "\(xtream.accounts.count) account(s)")) {
                        selectTab(2)
                    }
                    HomeCard(symbol: "gearshape",
                             title: tr("الإعدادات", "Settings"),
                             subtitle: tr("اللغة، وضع العرض، البيانات", "Language, appearance, data")) {
                        selectTab(4)
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
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
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                Text("WudCar").font(.system(size: 34, weight: .heavy))
                Text("وُد كار").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
            }
        } else {
            Image("LogoDay")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 264)
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
                Text(app.carStatusText).font(.subheadline).foregroundStyle(.secondary)
                if app.isCarConnected {
                    Text(tr("الفيديو في السيارة: ", "Video in car: ") + app.carVideoText)
                        .font(.subheadline)
                        .foregroundStyle(app.carVideoSupport == .unsupported ? Color.orange : .secondary)
                }
                if app.isCarConnected || app.carScreenActive {
                    Text(tr("شاشة السيارة: ", "Car screen: ") + app.carScreenText)
                        .font(.subheadline)
                        .foregroundStyle(app.carScreenActive ? Color.green : .secondary)
                }
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
