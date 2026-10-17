import SwiftUI

/// علامات التبويب — تقدر تدير تبويبات الهاتف وتبويبات السيارة من هنا
struct TabsSwitcherView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var side: BrowserSide

    init(initialSide: BrowserSide) {
        _side = State(initialValue: initialSide)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(tr("علامات التبويب", "Tabs"))
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Spacer()
            }
            Picker("", selection: $side) {
                Text(tr("الهاتف", "Phone")).tag(BrowserSide.phone)
                Text(tr("السيارة", "Car")).tag(BrowserSide.car)
            }
            .pickerStyle(.segmented)

            TabsGrid(store: TabStore.of(side), onDone: { dismiss() })
                .id(side)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .background(Color(white: 0.1).ignoresSafeArea())
    }
}

private struct TabsGrid: View {
    @ObservedObject var store: TabStore
    let onDone: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(store.tabs) { tab in
                        TabCard(
                            tab: tab,
                            snapshot: store.snapshots[tab.id],
                            isActive: tab.id == store.activeID,
                            onClose: { store.close(tab.id) }
                        )
                        .onTapGesture {
                            store.select(tab.id)
                            onDone()
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            HStack {
                Button(action: onDone) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(Color.wdAccent))
                }
                Spacer()
                Text(store.countText)
                    .font(.title3)
                    .foregroundStyle(.gray)
                Spacer()
                Button {
                    if store.isFull {
                        AppState.shared.showToast(tr("الحد الأقصى 8 علامات تبويب", "Maximum is 8 tabs"))
                    } else {
                        store.newTab()
                        onDone()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(Color(white: 0.16)))
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .padding(.bottom, 8)
        }
    }
}

private struct TabCard: View {
    let tab: BrowserTab
    let snapshot: UIImage?
    let isActive: Bool
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                Group {
                    if let snapshot {
                        Image(uiImage: snapshot).resizable().scaledToFill()
                    } else {
                        Color.black.overlay(
                            Image(systemName: tab.url == nil ? "square.grid.2x2" : "globe")
                                .font(.largeTitle)
                                .foregroundStyle(.gray)
                        )
                    }
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(isActive ? Color.wdAccent : Color.white.opacity(0.1), lineWidth: isActive ? 3 : 1)
                )

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.black.opacity(0.7)))
                }
                .padding(8)
            }
            .environment(\.layoutDirection, .leftToRight)

            Text(tab.url == nil ? tr("الرئيسية", "Home") : tab.displayTitle)
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }
}
