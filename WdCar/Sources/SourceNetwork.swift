import Foundation

/// Only user-selected servers and documented Plex authentication endpoints are contacted.
struct SourceNetwork {
    let session: URLSession
    init(session: URLSession = URLSession(configuration: .ephemeral, delegate: SourceRedirectPolicy(), delegateQueue: nil)) { self.session = session }
    func data(_ url: URL, method: String = "GET", headers: [String: String] = [:], body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url); request.httpMethod = method; request.httpBody = body; request.timeoutInterval = 30
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let bytes: URLSession.AsyncBytes; let response: URLResponse
        do { (bytes, response) = try await session.bytes(for: request) } catch { throw SourceFailure.network }
        guard let http = response as? HTTPURLResponse else { throw SourceFailure.badResponse }
        if [401,403].contains(http.statusCode) { throw SourceFailure.authentication }
        guard (200..<300).contains(http.statusCode) else { throw SourceFailure.network }
        if http.expectedContentLength > 15 * 1024 * 1024 { throw SourceFailure.tooLarge }
        var result = Data()
        for try await byte in bytes { result.append(byte); if result.count > 15 * 1024 * 1024 { throw SourceFailure.tooLarge } }
        return (result, http)
    }
    func streamResponse(_ url: URL) async throws -> HTTPURLResponse {
        var request = URLRequest(url: url); request.httpMethod = "HEAD"; request.timeoutInterval = 30
        let response: URLResponse
        do { (_, response) = try await session.data(for: request) } catch { throw SourceFailure.network }
        guard let http = response as? HTTPURLResponse else { throw SourceFailure.badResponse }
        if [401,403].contains(http.statusCode) { throw SourceFailure.authentication }
        guard (200..<300).contains(http.statusCode) || [405,501].contains(http.statusCode) else { throw SourceFailure.network }
        return http
    }
    func json(_ url: URL, method: String = "GET", headers: [String: String] = [:], body: [String: Any]? = nil) async throws -> [String: Any] {
        var headers = headers; headers["Accept"] = "application/json"
        if body != nil { headers["Content-Type"] = "application/json" }
        let (data, _) = try await data(url, method: method, headers: headers, body: try body.map { try JSONSerialization.data(withJSONObject: $0) })
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw SourceFailure.badResponse }; return object
    }
    static func endpoint(_ base: URL, _ path: String, query: [URLQueryItem] = []) throws -> URL {
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw SourceFailure.invalidURL }; return url
    }
    func authenticate(_ kind: MediaSource.Kind, credentials: SourceCredentials) async throws -> SourceCredentials {
        var result = credentials
        let base = try SourceInput.url(credentials.address)
        let json = try await json(Self.endpoint(base, "Users/AuthenticateByName"), method: "POST", headers: ["X-Emby-Authorization": Self.embyAuthorization], body: ["Username": credentials.username, "Pw": credentials.password])
        guard let token = json["AccessToken"] as? String, let user = json["User"] as? [String: Any], let id = user["Id"] as? String else { throw SourceFailure.authentication }
        result.token = token; result.userID = id; result.password = ""; return result
    }
    static var clientID: String {
        if let value = KeychainStore.get("wd.source.clientID") { return value }
        let value = UUID().uuidString; KeychainStore.set(value, for: "wd.source.clientID"); return value
    }
    static var embyAuthorization: String { "MediaBrowser Client=\"WudCar\", Device=\"iPhone\", DeviceId=\"\(clientID)\", Version=\"3.0.1\"" }
    func browse(_ source: MediaSource, credentials: SourceCredentials, parent: String? = nil) async throws -> [SourceMedia] {
        let base = try SourceInput.url(credentials.address)
        if source.kind == .plex { return try await plexBrowse(base, token: credentials.token, parent: parent) }
        var query = [URLQueryItem(name: "UserId", value: credentials.userID), URLQueryItem(name: "Limit", value: "3000"), URLQueryItem(name: "Fields", value: "MediaSources,UserData"), URLQueryItem(name: "SortBy", value: "SortName")]
        if let parent { query.append(URLQueryItem(name: "ParentId", value: parent)) }
        let path = parent == nil ? "Users/\(credentials.userID)/Views" : "Users/\(credentials.userID)/Items"
        let payload = try await json(Self.endpoint(base, path, query: query), headers: ["X-Emby-Token": credentials.token, "X-Emby-Authorization": Self.embyAuthorization])
        return try Self.decodeEmby(payload, base: base, token: credentials.token)
    }
    static func decodeEmby(_ json: [String: Any], base: URL, token: String) throws -> [SourceMedia] {
        guard let items = json["Items"] as? [[String: Any]] else { throw SourceFailure.badResponse }
        return try items.compactMap { item in
            guard let id = item["Id"] as? String, let title = item["Name"] as? String else { return nil }
            let folder = item["IsFolder"] as? Bool == true || ["Series", "Season", "CollectionFolder"].contains(item["Type"] as? String ?? "")
            let data = item["UserData"] as? [String: Any]
            let duration = (item["RunTimeTicks"] as? NSNumber)?.doubleValue ?? 0
            let position = (data?["PlaybackPositionTicks"] as? NSNumber)?.doubleValue ?? 0
            let stream: URL?
            if folder { stream = nil } else {
                let prefix = item["Type"] as? String == "Audio" ? "Audio" : "Videos"
                stream = try endpoint(base, "\(prefix)/\(id)/stream", query: [URLQueryItem(name: "static", value: "true"), URLQueryItem(name: "api_key", value: token)])
            }
            let artwork = try endpoint(base, "Items/\(id)/Images/Primary", query: [URLQueryItem(name: "maxWidth", value: "320"), URLQueryItem(name: "api_key", value: token)])
            return SourceMedia(id: id, title: title, url: stream, artwork: artwork, folder: folder, position: position / 10_000_000, duration: duration / 10_000_000)
        }
    }
    func plexPIN() async throws -> (Int, String) {
        let payload = try await json(URL(string: "https://plex.tv/api/v2/pins")!, method: "POST", headers: ["X-Plex-Product": "WudCar", "X-Plex-Client-Identifier": Self.clientID])
        guard let id = payload["id"] as? Int, let code = payload["code"] as? String else { throw SourceFailure.badResponse }; return (id, code)
    }
    func plexToken(pin: Int) async throws -> String? {
        let payload = try await json(URL(string: "https://plex.tv/api/v2/pins/\(pin)")!, headers: ["X-Plex-Client-Identifier": Self.clientID]); return payload["authToken"] as? String
    }
    struct PlexServer: Identifiable { let id: String; let name: String; let url: URL; let token: String }
    func plexServers(token: String) async throws -> [PlexServer] {
        let url = URL(string: "https://plex.tv/api/v2/resources?includeHttps=1&includeRelay=0")!
        let (data, _) = try await data(url, headers: ["Accept": "application/json", "X-Plex-Token": token, "X-Plex-Client-Identifier": Self.clientID])
        guard let values = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { throw SourceFailure.badResponse }
        return values.filter { $0["owned"] as? Bool == true && ($0["provides"] as? String ?? "").contains("server") }.flatMap { value -> [PlexServer] in
            (value["connections"] as? [[String: Any]] ?? []).compactMap { connection in
                guard connection["relay"] as? Bool != true, let uri = connection["uri"] as? String, let url = try? SourceInput.url(uri) else { return nil }
                return PlexServer(id: (value["clientIdentifier"] as? String ?? "") + uri, name: value["name"] as? String ?? "Plex", url: url, token: value["accessToken"] as? String ?? token)
            }
        }
    }
    func search(_ source: MediaSource, credentials: SourceCredentials, query: String) async throws -> [SourceMedia] {
        let base = try SourceInput.url(credentials.address)
        if source.kind == .plex {
            let payload = try await json(Self.endpoint(base, "hubs/search", query: [URLQueryItem(name: "query", value: query), URLQueryItem(name: "limit", value: "100")]), headers: ["X-Plex-Token": credentials.token, "X-Plex-Client-Identifier": Self.clientID])
            let root = payload["MediaContainer"] as? [String: Any] ?? [:]
            let hubs = root["Hub"] as? [[String: Any]] ?? []
            let entries = hubs.flatMap { $0["Metadata"] as? [[String: Any]] ?? [] }
            return try decodePlexEntries(entries, base: base, token: credentials.token)
        }
        let payload = try await json(Self.endpoint(base, "Users/\(credentials.userID)/Items", query: [URLQueryItem(name: "SearchTerm", value: query), URLQueryItem(name: "Recursive", value: "true"), URLQueryItem(name: "Limit", value: "3000"), URLQueryItem(name: "IncludeItemTypes", value: "Movie,Episode,Video,Audio")]), headers: ["X-Emby-Token": credentials.token, "X-Emby-Authorization": Self.embyAuthorization])
        return try Self.decodeEmby(payload, base: base, token: credentials.token)
    }
    private func plexBrowse(_ base: URL, token: String, parent: String?) async throws -> [SourceMedia] {
        let path = parent ?? "library/sections"
        guard !path.contains(".."), !path.contains("://") else { throw SourceFailure.invalidURL }
        let payload = try await json(Self.endpoint(base, path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), headers: ["X-Plex-Token": token, "X-Plex-Client-Identifier": Self.clientID])
        guard let container = payload["MediaContainer"] as? [String: Any] else { throw SourceFailure.badResponse }
        let entries = container["Metadata"] as? [[String: Any]] ?? container["Directory"] as? [[String: Any]] ?? []
        return try decodePlexEntries(entries, base: base, token: token)
    }
    private func decodePlexEntries(_ entries: [[String: Any]], base: URL, token: String) throws -> [SourceMedia] {
        return try entries.compactMap { entry in
            guard let title = entry["title"] as? String, let key = entry["key"] as? String else { return nil }
            let folder = ["show", "season", "movie", "artist", "photo"].contains(entry["type"] as? String ?? "") && entry["Media"] == nil
            let media = (entry["Media"] as? [[String: Any]])?.first
            let part = (media?["Part"] as? [[String: Any]])?.first
            let stream: URL?
            if let partKey = part?["key"] as? String { stream = try Self.endpoint(base, partKey.trimmingCharacters(in: CharacterSet(charactersIn: "/")), query: [URLQueryItem(name: "X-Plex-Token", value: token)]) } else { stream = nil }
            let next = key.hasPrefix("/") ? String(key.dropFirst()) : "library/sections/\(key)/all"
            return SourceMedia(id: next, title: title, url: stream, folder: folder || stream == nil, position: ((entry["viewOffset"] as? NSNumber)?.doubleValue ?? 0) / 1000, duration: ((entry["duration"] as? NSNumber)?.doubleValue ?? 0) / 1000)
        }
    }
}

/// Never forward a server token or password through a cross-origin redirect.
private final class SourceRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let from = response.url, let to = request.url else { completionHandler(nil); return }
        let credentials = ["X-Emby-Token", "X-Emby-Authorization", "X-Plex-Token"].contains { task.originalRequest?.value(forHTTPHeaderField: $0) != nil }
        let sameOrigin = from.scheme == to.scheme && from.host == to.host && from.port == to.port
        completionHandler(credentials && !sameOrigin ? nil : request)
    }
}
