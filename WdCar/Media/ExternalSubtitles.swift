import Foundation
import CoreFoundation
import Combine

struct SubtitleCue: Equatable {
    let start: Double
    let end: Double
    let text: String
}

enum SubtitleParser {
    static func parse(_ text: String) -> [SubtitleCue] {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        var result: [SubtitleCue] = []
        var index = 0
        while index < lines.count {
            let parts = lines[index].components(separatedBy: "-->")
            guard parts.count == 2, let start = timestamp(parts[0]), let end = timestamp(parts[1]), end > start else { index += 1; continue }
            index += 1
            var body: [String] = []
            while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                body.append(lines[index]); index += 1
            }
            let text = body.joined(separator: "\n").replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            result.append(.init(start: start, end: end, text: text))
        }
        return result.sorted { $0.start < $1.start }
    }

    static func timestamp(_ raw: String) -> Double? {
        guard let token = raw.trimmingCharacters(in: .whitespaces).split(separator: " ").first else { return nil }
        let parts = token.replacingOccurrences(of: ",", with: ".").split(separator: ":").map { Double($0) }
        guard (2...3).contains(parts.count), parts.allSatisfy({ $0 != nil }) else { return nil }
        let values = parts.compactMap { $0 }
        guard values.allSatisfy({ $0.isFinite && $0 >= 0 }), values.last! < 60, values[values.count - 2] < 60 else { return nil }
        return values.reduce(0) { $0 * 60 + $1 }
    }
}

final class ExternalSubtitles: ObservableObject {
    static let shared = ExternalSubtitles()
    @Published private(set) var cues: [SubtitleCue] = []
    @Published private(set) var mediaURL: URL?
    func load(_ url: URL, for mediaURL: URL) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 2 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        let parsed = SubtitleParser.parse(try String(contentsOf: url, encoding: PlayerPreferences.text("subtitleEncoding", "utf8") == "windows1256" ? String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.windowsArabic.rawValue))) : .utf8))
        guard !parsed.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        self.mediaURL = mediaURL
        cues = parsed
    }
    func text(at time: Double, mediaURL: URL?) -> String {
        guard self.mediaURL == mediaURL else { return "" }
        return cues.filter { $0.start <= time && time < $0.end }.map(\.text).joined(separator: "\n")
    }
}
