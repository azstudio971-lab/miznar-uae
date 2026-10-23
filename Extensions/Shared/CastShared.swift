import Foundation
import ActivityKit

struct WudCarPlaybackAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var elapsed: Double
        var duration: Double
        var playing: Bool
        var casting: Bool
    }
    var appName = "WudCar"
}
enum CastShared {
    static let group = "group.com.azstudio.wudcar"
    static var directory: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) }
    static var frame: URL? { directory?.appendingPathComponent("relay-frame.jpg") }
    static var state: URL? { directory?.appendingPathComponent("relay-state.json") }
    static var nowPlaying: URL? { directory?.appendingPathComponent("cast-now-playing.json") }
    struct RelayState: Codable {
        var active: Bool
        var updated: Date
    }
}
