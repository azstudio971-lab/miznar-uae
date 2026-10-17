import Foundation

/// عميل Xtream Codes (واجهة player_api.php القياسية)
struct XtreamClient {
    let account: XtreamAccount
    private let password: String?

    init(account: XtreamAccount, password: String? = nil) {
        self.account = account
        self.password = password ?? account.password
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    // MARK: الطلبات

    func authenticate() async throws -> XtreamAccountInfo {
        let json = try await request([:])
        guard let root = json as? [String: Any], let user = root["user_info"] as? [String: Any] else {
            throw XtreamError.badResponse
        }
        if Self.string(user["auth"]) != "1" { throw XtreamError.unauthorized }
        let status = Self.string(user["status"]) ?? "Active"
        if status.lowercased() != "active" { throw XtreamError.expired }
        var expiry: Date?
        if let raw = Self.string(user["exp_date"]), let seconds = TimeInterval(raw) {
            expiry = Date(timeIntervalSince1970: seconds)
        }
        return XtreamAccountInfo(status: status, expiry: expiry, maxConnections: Self.string(user["max_connections"]))
    }

    func categories(_ kind: XtreamKind) async throws -> [XtreamCategory] {
        let action = kind == .live ? "get_live_categories" : "get_vod_categories"
        guard let list = try await request(["action": action]) as? [[String: Any]] else { return [] }
        return list.compactMap { item in
            guard let id = Self.string(item["category_id"]) else { return nil }
            return XtreamCategory(id: id, name: Self.string(item["category_name"]) ?? id)
        }
    }

    func streams(_ kind: XtreamKind, categoryID: String?) async throws -> [XtreamStream] {
        var params = ["action": kind == .live ? "get_live_streams" : "get_vod_streams"]
        if let categoryID { params["category_id"] = categoryID }
        guard let list = try await request(params) as? [[String: Any]] else { return [] }
        return list.compactMap { item in
            guard let id = Self.string(item["stream_id"]) else { return nil }
            let icon = Self.string(item["stream_icon"]).flatMap { $0.isEmpty ? nil : URL(string: $0) }
            return XtreamStream(id: id,
                                name: Self.string(item["name"]) ?? id,
                                icon: icon,
                                containerExtension: Self.string(item["container_extension"]),
                                kind: kind)
        }
    }

    /// رابط التشغيل: البث المباشر بصيغة HLS (m3u8)، والأفلام بامتداد الملف من السيرفر
    func playbackURL(for stream: XtreamStream) -> URL? {
        guard let base = account.baseURL, let password else { return nil }
        let user = Self.pathEncode(account.username)
        let pass = Self.pathEncode(password)
        switch stream.kind {
        case .live:
            return URL(string: "\(base.absoluteString)/live/\(user)/\(pass)/\(stream.id).m3u8")
        case .movies:
            let ext = (stream.containerExtension?.isEmpty == false) ? stream.containerExtension! : "mp4"
            return URL(string: "\(base.absoluteString)/movie/\(user)/\(pass)/\(stream.id).\(ext)")
        }
    }

    // MARK: داخلي

    private func request(_ params: [String: String]) async throws -> Any {
        guard let base = account.baseURL else { throw XtreamError.invalidServer }
        guard let password, !password.isEmpty else { throw XtreamError.missingPassword }
        guard var components = URLComponents(url: base.appendingPathComponent("player_api.php"),
                                             resolvingAgainstBaseURL: false) else {
            throw XtreamError.invalidServer
        }
        var items = [URLQueryItem(name: "username", value: account.username),
                     URLQueryItem(name: "password", value: password)]
        items += params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        components.queryItems = items
        guard let url = components.url else { throw XtreamError.invalidServer }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await Self.session.data(from: url)
        } catch {
            throw XtreamError.network(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 || http.statusCode == 403 { throw XtreamError.unauthorized }
            guard (200..<300).contains(http.statusCode) else { throw XtreamError.network("HTTP \(http.statusCode)") }
        }
        guard let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            throw XtreamError.badResponse
        }
        return json
    }

    /// بعض السيرفرات ترجع الأرقام كنص وبعضها كرقم
    static func string(_ value: Any?) -> String? {
        switch value {
        case let string as String: return string
        case let number as NSNumber: return number.stringValue
        default: return nil
        }
    }

    private static func pathEncode(_ text: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }
}
