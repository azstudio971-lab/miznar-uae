import XCTest
import CarPlay
import CoreImage
import Vision
@testable import WdCar

final class SourceTestProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, String))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let result = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: result.0, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": request.httpMethod == "HEAD" ? "video/mp4" : "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(result.1.utf8)); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
@MainActor final class SourceTests: XCTestCase {
    private func network() -> SourceNetwork {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [SourceTestProtocol.self]
        return SourceNetwork(session: URLSession(configuration: config))
    }
    func testM3UTextGroupsLogosAndDuplicateRemoval() throws {
        let items = try SourceInput.playlist("#EXTM3U\n#EXTINF:-1 tvg-logo=\"https://example.test/logo.png\" group-title=\"Kids\",Test\nhttps://example.test/live.m3u8\nhttps://example.test/live.m3u8")
        XCTAssertEqual(items.count, 1); XCTAssertEqual(items[0].title, "Test"); XCTAssertEqual(items[0].group, "Kids")
        XCTAssertEqual(items[0].artwork?.lastPathComponent, "logo.png")
        XCTAssertThrowsError(try SourceInput.playlist("<html>Login</html>"))
        XCTAssertThrowsError(try SourceInput.playlist("not a playlist"))
        XCTAssertThrowsError(try SourceInput.url("javascript:alert(1)"))
    }
    func testConfigAndSmartPaste() {
        let links = SourceInput.links("{\"a\":\"https://one.test/a.m3u\",\"b\":\"https://two.test/live.m3u8\",\"c\":\"https://one.test/a.m3u\"}")
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(SourceInput.smartKind("https://one.test/a.m3u"), .playlist)
        XCTAssertEqual(SourceInput.smartKind("https://two.test/live.m3u8"), .stream)
        XCTAssertEqual(SourceInput.smartKind("#EXTM3U\nhttps://one.test/a"), .pasted)
        XCTAssertEqual(SourceInput.smartKind("https://one.test/a\nhttps://two.test/b"), .config)
    }
    func testJellyfinAndEmbyAuthenticationAndHierarchy() async throws {
        for kind in [MediaSource.Kind.jellyfin, .emby] {
            var calls: [String] = []
            SourceTestProtocol.handler = { request in
                calls.append(request.url!.path)
                if request.url!.path.hasSuffix("AuthenticateByName") {
                    XCTAssertEqual(request.httpMethod, "POST")
                    XCTAssertNotNil(request.value(forHTTPHeaderField: "X-Emby-Authorization"))
                    return (200, "{\"AccessToken\":\"secret\",\"User\":{\"Id\":\"u1\"}}")
                }
                XCTAssertEqual(request.value(forHTTPHeaderField: "X-Emby-Token"), "secret")
                if request.url!.path.hasSuffix("Views") { return (200, "{\"Items\":[{\"Id\":\"library\",\"Name\":\"Movies\",\"IsFolder\":true}]}") }
                return (200, "{\"Items\":[{\"Id\":\"movie\",\"Name\":\"Sample\",\"Type\":\"Movie\",\"RunTimeTicks\":100000000,\"UserData\":{\"PlaybackPositionTicks\":25000000}}]}")
            }
            let client = network(); let source = MediaSource(name: "Test", kind: kind)
            let credentials = try await client.authenticate(kind, credentials: SourceCredentials(address: "https://server.test", username: "u", password: "p"))
            XCTAssertEqual(credentials.token, "secret"); XCTAssertTrue(credentials.password.isEmpty)
            let libraries = try await client.browse(source, credentials: credentials)
            XCTAssertTrue(libraries[0].folder)
            let items = try await client.browse(source, credentials: credentials, parent: libraries[0].id)
            XCTAssertFalse(items[0].folder); XCTAssertEqual(items[0].position, 2.5); XCTAssertEqual(items[0].duration, 10)
            XCTAssertTrue(items[0].url!.absoluteString.contains("Videos/movie/stream"))
            XCTAssertEqual(calls.count, 3)
        }
        SourceTestProtocol.handler = { _ in (401, "{}") }
        do { _ = try await network().authenticate(.jellyfin, credentials: SourceCredentials(address: "https://server.test")); XCTFail("401 accepted") } catch { XCTAssertTrue(error is SourceFailure) }
    }
    func testPlexPINOwnedServersAndDirectMedia() async throws {
        SourceTestProtocol.handler = { request in
            switch request.url!.path {
            case "/api/v2/pins": return (200, "{\"id\":123,\"code\":\"ABCD\"}")
            case "/api/v2/pins/123": return (200, "{\"authToken\":\"token\"}")
            case "/api/v2/resources": return (200, "[{\"owned\":true,\"provides\":\"server\",\"name\":\"Home\",\"clientIdentifier\":\"s1\",\"accessToken\":\"server-token\",\"connections\":[{\"uri\":\"https://home.plex.direct:32400\",\"relay\":false}]},{\"owned\":false,\"provides\":\"server\",\"connections\":[{\"uri\":\"https://other.test\"}]}]")
            case "/library/sections": return (200, "{\"MediaContainer\":{\"Directory\":[{\"key\":\"1\",\"title\":\"Movies\",\"type\":\"movie\"}]}}")
            default: return (200, "{\"MediaContainer\":{\"Metadata\":[{\"key\":\"/library/metadata/42\",\"title\":\"Film\",\"duration\":10000,\"Media\":[{\"Part\":[{\"key\":\"/library/parts/42/file.mp4\"}]}]}]}}")
            }
        }
        let client = network(); let pin = try await client.plexPIN()
        XCTAssertEqual(pin.0, 123); XCTAssertEqual(pin.1, "ABCD")
        let token = try await client.plexToken(pin: pin.0); XCTAssertEqual(token, "token")
        let servers = try await client.plexServers(token: token!); XCTAssertEqual(servers.count, 1)
        let credentials = SourceCredentials(address: servers[0].url.absoluteString, token: servers[0].token)
        let source = MediaSource(name: "Plex", kind: .plex)
        let libraries = try await client.browse(source, credentials: credentials)
        XCTAssertTrue(libraries[0].folder)
        let film = try await client.browse(source, credentials: credentials, parent: libraries[0].id)
        XCTAssertEqual(film[0].url?.path, "/library/parts/42/file.mp4"); XCTAssertEqual(film[0].duration, 10)
    }
    func testEncryptedSourcePersistenceRefreshAndRemoval() async throws {
        let store = SourceStore.shared
        let source = try await store.add(name: "Source test", kind: .pasted, credentials: SourceCredentials(text: "#EXTM3U\nhttps://example.test/secret-stream.m3u8"))
        defer { store.remove(source) }
        XCTAssertEqual(store.cached(source).count, 1)
        XCTAssertNotNil(KeychainStore.get(source.secretKey))
        let url = MediaLibrary.directory.appendingPathComponent("Sources/" + source.id.uuidString + ".sealed")
        let bytes = try Data(contentsOf: url)
        XCTAssertFalse(String(decoding: bytes, as: UTF8.self).contains("secret-stream"))
        store.rename(source, name: "Renamed"); store.hide(source)
        XCTAssertEqual(store.sources.first { $0.id == source.id }?.name, "Renamed")
        XCTAssertTrue(store.sources.first { $0.id == source.id }!.hidden)
        try await store.refresh(source)
        XCTAssertEqual(store.cached(source).count, 1)
        store.remove(source)
        XCTAssertNil(KeychainStore.get(source.secretKey)); XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
    func testURLPlaylistSingleStreamConfigAndInvalidContent() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = SourceStore(network: network(), directory: root)
        defer { for source in store.sources { store.remove(source) }; try? FileManager.default.removeItem(at: root) }
        SourceTestProtocol.handler = { request in
            if request.url!.host == "bad.test" { return (401, "denied") }
            if request.httpMethod == "HEAD" { return (200, "") }
            return (200, "#EXTM3U\n#EXTINF:-1 group-title=\"News\",Channel\nhttps://stream.test/live.m3u8")
        }
        let source = try await store.add(name: "Remote", kind: .playlist, credentials: SourceCredentials(address: "https://ok.test/list.m3u"))
        XCTAssertEqual(source.count, 1)
        let counts = await store.addConfig("https://ok.test/list2.m3u\nhttps://bad.test/list.m3u", name: "Config")
        XCTAssertEqual(counts.added, 1); XCTAssertEqual(counts.failed, 1)
        let stream = try await store.add(name: "Single", kind: .stream, credentials: SourceCredentials(address: "https://stream.test/live.m3u8"))
        XCTAssertEqual(store.cached(stream).count, 1); XCTAssertTrue(store.cached(stream)[0].isLive)
        let before = store.sources.count
        do { _ = try await store.add(name: "Invalid", kind: .pasted, credentials: SourceCredentials(text: "<html>Login</html>")); XCTFail("Invalid source persisted") } catch {}
        XCTAssertEqual(store.sources.count, before)
        SourceTestProtocol.handler = { _ in (200, "<html>Website</html>") }
        do { _ = try await store.add(name: "Website", kind: .playlist, credentials: SourceCredentials(address: "https://web.test")); XCTFail("HTML accepted") } catch {}
        XCTAssertEqual(store.sources.count, before)
    }
    func testCategoryMappingAndExpiredXtreamMetadata() throws {
        XCTAssertEqual(MediaCategory.classify("Kids"), .kids)
        XCTAssertEqual(MediaCategory.classify("أخبار"), .news)
        XCTAssertEqual(MediaCategory.classify("Uncategorized"), .other)
        let info = try XtreamClient.decodeAccountInfo(["auth": 0, "status": "Expired", "exp_date": "1700000000"])
        XCTAssertEqual(info.status, "Expired"); XCTAssertFalse(info.authenticated); XCTAssertNotNil(info.expiry)
        XCTAssertThrowsError(try XtreamClient.decodeAccountInfo(["auth": 0, "status": "Active"]))
    }
    func testLocalSearchHistoryAndFolderOrdering() async throws {
        let library = MediaLibrary.shared
        let before = Set(library.items.map(\.id))
        try library.addRemote(title: "Unique-search-fixture", url: URL(string: "https://example.test/" + UUID().uuidString + ".mp4")!, isLive: false)
        let item = try XCTUnwrap(library.items.first { !before.contains($0.id) })
        defer { library.remove(item.id) }
        let search = MediaSearch()
        let history = UserDefaults.standard.object(forKey: "wd.media.searchHistory")
        defer { if let history { UserDefaults.standard.set(history, forKey: "wd.media.searchHistory") } else { UserDefaults.standard.removeObject(forKey: "wd.media.searchHistory") } }
        search.remember("fixture"); search.remember("fixture")
        XCTAssertEqual(search.history.filter { $0 == "fixture" }.count, 1)
        await search.search("Unique-search-fixture", includeNetwork: false)
        XCTAssertEqual(search.results.count, 1)
        search.clear(); XCTAssertTrue(search.history.isEmpty)
        let folders = MediaFolders.shared
        folders.create("Test folder"); let folder = try XCTUnwrap(folders.folders.last)
        defer { folders.remove(folder.id) }
        folders.add([item.id], to: folder.id)
        XCTAssertEqual(folders.members(folder.id).map(\.id), [item.id])
        folders.rename(folder.id, name: "Renamed")
        XCTAssertEqual(folders.folders.first { $0.id == folder.id }?.name, "Renamed")
        folders.setMembers([], in: folder.id); XCTAssertTrue(folders.members(folder.id).isEmpty)
    }
    func testQRImageAndNativeCastTabOrder() throws {
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(Data("https://example.test/list.m3u".utf8), forKey: "inputMessage")
        let image = try XCTUnwrap(filter.outputImage).transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let cg = try XCTUnwrap(CIContext().createCGImage(image, from: image.extent))
        let request = VNDetectBarcodesRequest(); request.symbologies = [.qr]
        try VNImageRequestHandler(cgImage: cg).perform([request])
        XCTAssertEqual(request.results?.first?.payloadStringValue, "https://example.test/list.m3u")
        XCTAssertEqual(CarTemplateUI.tabOrder, ["library", "tv", "favorites", "cast"])
    }
}
