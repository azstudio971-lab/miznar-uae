import Foundation

struct HLSQuality: Identifiable, Equatable {
    var id: Double { bandwidth }
    let bandwidth: Double
    let width: Double
    let height: Double
    var title: String { height > 0 ? "\(Int(height))p" : "\(Int(bandwidth / 1000)) kbps" }
    static func parse(_ text: String) -> [HLSQuality] {
        var values: [HLSQuality] = []
        for line in text.components(separatedBy: .newlines) where line.hasPrefix("#EXT-X-STREAM-INF:") {
            let attributes = String(line.dropFirst("#EXT-X-STREAM-INF:".count))
            let fields = attributes.split(separator: ",").reduce(into: [String:String]()) { result, part in
                let pair = part.split(separator: "=", maxSplits: 1); if pair.count == 2 { result[String(pair[0])] = String(pair[1]) }
            }
            guard let bandwidth = fields["BANDWIDTH"].flatMap(Double.init), bandwidth > 0 else { continue }
            let size = (fields["RESOLUTION"] ?? "").split(separator: "x").compactMap { Double($0) }
            let item = HLSQuality(bandwidth: bandwidth, width: size.count == 2 ? size[0] : 0, height: size.count == 2 ? size[1] : 0)
            if !values.contains(where: { $0.bandwidth == bandwidth }) { values.append(item) }
        }
        return values.sorted { $0.bandwidth < $1.bandwidth }
    }
    static func load(_ url: URL) async throws -> [HLSQuality] {
        let (data, _) = try await SourceNetwork().data(url)
        return parse(String(decoding: data, as: UTF8.self))
    }
}
