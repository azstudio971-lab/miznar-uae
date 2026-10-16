#if DEBUG
import WebKit

// Deterministic, offline UI-test pages. Unregistered outside the explicit DEBUG
// test launch mode; never pretends to be YouTube/TikTok or accesses real accounts.
final class BrowserTestFixtures: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let url = urlSchemeTask.request.url!
        let second = url.path == "/two"
        let html = """
        <!doctype html><meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(second ? "Second fixture" : "First fixture")</title>
        <style>body{font:20px -apple-system;padding:24px;color:#fff;background:#082e36}a{display:block;color:#ffd581;padding:20px}input,button{font:20px -apple-system;padding:12px}</style>
        <h1>\(second ? "Second page" : "First page")</h1>
        <a href="wudcar-test://fixture/two">Next page</a>
        <a href="wudcar-test://fixture/two" target="_blank">Open new tab</a>
        <label>Search text<input aria-label="Search text"></label>
        <button onclick="document.title='Updated fixture'">Change title</button>
        """
        let data = Data(html.utf8)
        urlSchemeTask.didReceive(URLResponse(url: url, mimeType: "text/html", expectedContentLength: data.count, textEncodingName: "utf-8"))
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}
#endif
