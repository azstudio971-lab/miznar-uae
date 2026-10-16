import Foundation

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    checks += 1
    guard condition() else { fatalError("Browser policy failed: \(name)") }
}
check(BrowserPolicy.destination(for: "youtube.com")?.absoluteString == "https://youtube.com", "bare domain")
check(BrowserPolicy.destination(for: "  https://www.youtube.com/watch?v=test&start=4  ")?.query == "v=test&start=4", "query preserved")
check(BrowserPolicy.destination(for: "youtube.com:443/watch?v=test")?.port == 443, "hostname port")
let arabic = BrowserPolicy.destination(for: "ود كار تجارب")!
check(URLComponents(url: arabic, resolvingAgainstBaseURL: false)?.queryItems?.first?.value == "ود كار تجارب", "Arabic search encoded once")
check(BrowserPolicy.destination(for: "road & music + cars")?.host == "www.google.com", "plain text search")
for value in ["", "  ", "http://youtube.com", "javascript:alert(1)", "file:///etc/passwd", "data:text/html,hello", "mailto:a@b.com", "youtube://watch", "https://", "https://a b.com", "https://user:pass@example.com", "https://user@example.com", "https://user%40name@example.com", "https://example.com\\@evil.test"] {
    check(BrowserPolicy.destination(for: value) == nil, "reject \(value)")
}
check(BrowserPolicy.siteAsset(for: URL(string: "https://www.youtube.com/watch?v=x")) == "BrowserYouTube", "YouTube asset")
check(BrowserPolicy.siteAsset(for: URL(string: "https://m.tiktok.com")) == "BrowserTikTok", "TikTok subdomain")
check(BrowserPolicy.siteAsset(for: URL(string: "https://youtube.com.evil.test")) == nil, "host suffix spoof")
check(BrowserPolicy.siteAsset(for: URL(string: "https://notyoutube.com")) == nil, "host prefix spoof")
check(BrowserPolicy.normalizedHost(URL(string: "https://WWW.YOUTUBE.COM")) == "youtube.com", "case-insensitive seed deduplication")
check(BrowserPolicy.canAddTab(count: 7), "eighth tab allowed")
check(!BrowserPolicy.canAddTab(count: 8), "ninth tab blocked")
check(BrowserPolicy.zoom(4) == 2 && BrowserPolicy.zoom(0) == 0.5, "zoom limits")
check(BrowserPolicy.zoom(1.2) == 1.2, "zoom in range")
print("Passed \(checks) browser policy checks")
