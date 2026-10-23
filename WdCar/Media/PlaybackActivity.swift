import Foundation
import ActivityKit
import WidgetKit
import UIKit

final class PlaybackActivity {
    static let shared = PlaybackActivity()
    private var activity: Activity<WudCarPlaybackAttributes>?
    private var lastUpdate = Date.distantPast
    private var previousTitle = ""
    func update(title: String, elapsed: Double, duration: Double, playing: Bool, casting: Bool) {
        guard title != previousTitle || Date().timeIntervalSince(lastUpdate) >= 15 else { return }
        previousTitle = title; lastUpdate = Date()
        let state = WudCarPlaybackAttributes.ContentState(title: title, elapsed: max(0, elapsed), duration: max(0, duration), playing: playing, casting: casting)
        if let url = CastShared.nowPlaying { try? JSONEncoder().encode(state).write(to: url, options: [.atomic, .completeFileProtection]) }
        WidgetCenter.shared.reloadTimelines(ofKind: "WudCarCast")
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if let activity { Task { await activity.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(60))) } }
        else if UIApplication.shared.applicationState == .active {
            activity = try? Activity.request(attributes: WudCarPlaybackAttributes(), content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(60)), pushType: nil)
        }
    }
    func end() {
        if let activity { Task { await activity.end(nil, dismissalPolicy: .immediate) } }
        activity = nil; previousTitle = ""; lastUpdate = .distantPast
        if let file = CastShared.nowPlaying { try? FileManager.default.removeItem(at: file) }
        WidgetCenter.shared.reloadTimelines(ofKind: "WudCarCast")
    }
}
