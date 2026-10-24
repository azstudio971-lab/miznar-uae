import SwiftUI

/// The external-display route reads the same library as the phone and template UI.
/// Management stays on iPhone; every playback request targets the car display.
struct CarMediaLibraryView: View {
    @ObservedObject private var library = MediaLibrary.shared
    @ObservedObject private var m3u = M3UStore.shared
    @ObservedObject private var xtream = XtreamStore.shared

    var body: some View {
        NavigationStack {
            List {
                mediaSection(carTr("متابعة المشاهدة", "Continue watching"), library.continueWatching)
                if !library.playlists.isEmpty {
                    Section(carTr("قوائم التشغيل", "Playlists")) {
                        ForEach(library.playlists) { playlist in
                            NavigationLink {
                                CarMediaPlaylistView(id: playlist.id)
                            } label: {
                                Label(playlist.title, systemImage: playlist.favorite ? "star.fill" : "list.bullet")
                            }
                        }
                    }
                }
                mediaSection(carTr("الفيديوهات", "Videos"), library.items.filter { $0.localFilename != nil && !$0.isAudio })
                mediaSection(carTr("الصوتيات", "Audio"), library.items.filter { $0.localFilename != nil && $0.isAudio })
                Section(carTr("القنوات", "Channels")) {
                    NavigationLink(carTr("القنوات المفضلة", "Favorite channels")) {
                        CarMediaItemsView(title: carTr("القنوات المفضلة", "Favorite channels"), items: library.items.filter { $0.localFilename == nil && $0.favorite })
                    }
                    ForEach(m3u.playlists) { playlist in
                        NavigationLink(playlist.name) { M3UEntriesView(playlist: playlist, presentPlaybackOnPhone: false) }
                    }
                    ForEach(xtream.accounts) { account in
                        NavigationLink(account.name) { XtreamAccountView(account: account, presentPlaybackOnPhone: false) }
                    }
                }
                mediaSection(carTr("المضافة حديثاً", "Recently added"), Array(library.items.sorted { $0.added > $1.added }.prefix(20)))
                Section {
                    Text(carTr("أضف ملفاتك ورتّب قوائم التشغيل من مكتبة iPhone.", "Add files and organize playlists in the iPhone library."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(carTr("مكتبة الفيديو", "Video Library"))
            .accessibilityIdentifier("car.library.content")
        }
        .environment(\.layoutDirection, WDSettings.carLanguage == "ar" ? .rightToLeft : .leftToRight)
    }

    @ViewBuilder private func mediaSection(_ title: String, _ items: [LibraryMedia]) -> some View {
        if !items.isEmpty {
            Section(title) { ForEach(items) { CarMediaRow(item: $0, queue: items) } }
        }
    }
}

private struct CarMediaPlaylistView: View {
    let id: UUID
    @ObservedObject private var library = MediaLibrary.shared
    var body: some View {
        let playlist = library.playlists.first { $0.id == id }
        CarMediaItemsView(title: playlist?.title ?? "", items: playlist.map { library.contents($0) } ?? [])
    }
}

private struct CarMediaItemsView: View {
    let title: String
    let items: [LibraryMedia]
    var body: some View {
        List(items) { CarMediaRow(item: $0, queue: items) }.navigationTitle(title)
    }
}

private struct CarMediaRow: View {
    let item: LibraryMedia
    let queue: [LibraryMedia]
    var body: some View {
        Button {
            PlaybackManager.shared.playQueue(queue.compactMap(\.playbackItem), startingAt: item.url, presentOnPhone: false)
        } label: {
            HStack(spacing: 14) {
                if let image = UIImage(contentsOfFile: MediaLibrary.shared.thumbnailURL(item.id).path) {
                    Image(uiImage: image).resizable().scaledToFit().frame(width: 72, height: 48)
                } else {
                    Image(systemName: item.isAudio ? "waveform" : "play.rectangle").frame(width: 72, height: 48)
                }
                VStack(alignment: .leading) {
                    Text(item.title).foregroundStyle(.primary)
                    if let duration = item.duration, duration > 0 {
                        Text(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond)))
                            .font(.caption).foregroundStyle(.secondary)
                        if item.position > 0 { ProgressView(value: min(1, item.position / duration)) }
                    }
                }
                if item.favorite { Image(systemName: "star.fill") }
            }.frame(minHeight: 52)
        }
        .accessibilityIdentifier("car.library.item.\(item.id.uuidString)")
    }
}
