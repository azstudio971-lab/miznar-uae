import Foundation

// Kept independent of WebKit so URL handling and tab limits can be tested on CI.
enum BrowserPolicy {
    static let maximumTabs = 8
    static let minimumZoom = 0.5
    static let maximumZoom = 2.0

    static func websiteURL(_ input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: { $0.isWhitespace || $0.isNewline }),
              !text.contains("\\"),
              let parts = URLComponents(string: text), parts.scheme?.lowercased() == "https",
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
              let url = parts.url else { return nil }
        return url
    }

    static func destination(for input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        // Never turn a supplied scheme into a search query (javascript:, file:, app links).
        if text.contains("://") { return websiteURL(text) }
        if text.range(of: "^[A-Za-z][A-Za-z0-9+.-]*:", options: .regularExpression) != nil {
            // A bare hostname with a numeric port is still a website.
            if text.range(of: "^[^ /:]+\\.[^ /:]+:[0-9]+(?:/|$)", options: .regularExpression) != nil {
                return websiteURL("https://" + text)
            }
            return nil
        }
        if !text.contains(where: { $0.isWhitespace }), text.contains(".") {
            return websiteURL("https://" + text)
        }
        var components = URLComponents(string: "https://www.google.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: text)]
        return components.url
    }

    static func normalizedHost(_ url: URL?) -> String {
        let host = url?.host?.lowercased() ?? ""
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    static func siteAsset(for url: URL?) -> String? {
        let host = normalizedHost(url)
        if host == "youtube.com" || host.hasSuffix(".youtube.com") { return "BrowserYouTube" }
        if host == "tiktok.com" || host.hasSuffix(".tiktok.com") { return "BrowserTikTok" }
        return nil
    }

    static func zoom(_ value: Double) -> Double { min(maximumZoom, max(minimumZoom, value)) }
    static func canAddTab(count: Int) -> Bool { count < maximumTabs }
}
