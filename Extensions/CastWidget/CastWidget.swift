import WidgetKit
import SwiftUI
import ActivityKit

struct CastEntry: TimelineEntry {
    let date: Date
    let title: String
    let playing: Bool
    let casting: Bool
}
struct CastProvider: TimelineProvider {
    func placeholder(in context: Context) -> CastEntry { CastEntry(date: Date(), title: "WudCar", playing: false, casting: false) }
    func getSnapshot(in context: Context, completion: @escaping (CastEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CastEntry>) -> Void) { completion(Timeline(entries: [entry()], policy: .after(Date().addingTimeInterval(60)))) }
    private func entry() -> CastEntry {
        let state = CastShared.nowPlaying.flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(WudCarPlaybackAttributes.ContentState.self, from: $0) }
        let relay = CastShared.state.flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(CastShared.RelayState.self, from: $0) }
        return CastEntry(date: Date(), title: state?.title ?? "WudCar", playing: state?.playing ?? false, casting: state?.casting == true || (relay?.active == true && Date().timeIntervalSince(relay?.updated ?? .distantPast) < 3))
    }
}
struct WudCarCastWidget: Widget {
    let kind = "WudCarCast"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CastProvider()) { entry in
            VStack(alignment: .leading, spacing: 10) {
                Label("WudCar", systemImage: "airplay.video").font(.headline)
                Text(entry.title).lineLimit(2)
                Image(systemName: entry.playing ? "play.fill" : "pause.fill")
                Text(entry.casting ? "Cast • On" : "Cast").font(.caption)
            }.frame(maxWidth: .infinity, alignment: .leading).containerBackground(.black.gradient, for: .widget)
                .widgetURL(URL(string: "wudcar://cast"))
        }.configurationDisplayName("WudCar Cast").description("Open Cast and view current playback.")
            .supportedFamilies([.systemSmall])
    }
}
struct WudCarLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WudCarPlaybackAttributes.self) { context in
            HStack {
                Image(systemName: "play.rectangle.fill")
                VStack(alignment: .leading) { Text(context.state.title).lineLimit(1); Text(context.state.playing ? "WudCar • Playing" : "WudCar • Paused").font(.caption) }
                Spacer()
                Image(systemName: context.state.casting ? "airplay.video" : "iphone")
            }.padding().activityBackgroundTint(.black).foregroundStyle(.white).widgetURL(URL(string: "wudcar://cast"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: "play.rectangle.fill") }
                DynamicIslandExpandedRegion(.center) { Text(context.state.title).lineLimit(1) }
                DynamicIslandExpandedRegion(.trailing) { Image(systemName: context.state.playing ? "play.fill" : "pause.fill") }
                DynamicIslandExpandedRegion(.bottom) { if context.state.duration > 0 { ProgressView(value: min(1, max(0, context.state.elapsed / context.state.duration))) } }
            } compactLeading: { Image(systemName: "play.rectangle.fill") } compactTrailing: { Image(systemName: context.state.casting ? "airplay.video" : "music.note") } minimal: { Image(systemName: "play.rectangle.fill") }
                .widgetURL(URL(string: "wudcar://cast"))
        }
    }
}
@main struct WudCarWidgets: WidgetBundle {
    var body: some Widget { WudCarCastWidget(); WudCarLiveActivity() }
}
