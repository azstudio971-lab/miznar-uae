import Foundation
import Network

/// Actual HTTP HLS playback, without depending on an external CDN or its uptime.
final class HLSTestServer {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "wd.tests.hls")
    private var connections: [NWConnection] = []
    private var port: UInt16 = 0
    var url: URL { URL(string: "http://127.0.0.1:\(port)/local.m3u8")! }
    private init() throws { listener = try NWListener(using: .tcp, on: .any) }
    static func start() async throws -> HLSTestServer {
        let server = try HLSTestServer()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var completed = false
            server.listener.stateUpdateHandler = { state in
                guard !completed else { return }
                switch state {
                case .ready:
                    completed = true
                    server.port = server.listener.port!.rawValue
                    continuation.resume()
                case .failed(let error):
                    completed = true
                    continuation.resume(throwing: error)
                default: break
                }
            }
            server.listener.newConnectionHandler = { connection in
                server.connections.append(connection)
                connection.start(queue: server.queue)
                server.receive(connection, accumulated: Data())
            }
            server.listener.start(queue: server.queue)
        }
        return server
    }
    private func receive(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, complete, error in
            guard let self else { return }
            var request = accumulated
            request.append(data ?? Data())
            guard let text = String(data: request, encoding: .utf8), text.contains("\r\n\r\n") else {
                if complete || error != nil { connection.cancel() }
                else { self.receive(connection, accumulated: request) }
                return
            }
            let path = text.components(separatedBy: " ").dropFirst().first ?? ""
            let filename = URL(string: "http://localhost" + path)?.lastPathComponent ?? ""
            let name = (filename as NSString).deletingPathExtension
            let ext = (filename as NSString).pathExtension
            let allowed = name == "local" || (name.hasPrefix("local") && ext == "ts")
            let resource = allowed ? Bundle(for: HLSTestServer.self).url(forResource: name, withExtension: ext) : nil
            let body = resource.flatMap { try? Data(contentsOf: $0) }
            let status = body == nil ? "404 Not Found" : "200 OK"
            let mime = ext == "m3u8" ? "application/vnd.apple.mpegurl" : "video/mp2t"
            let payload = body ?? Data()
            var response = Data("HTTP/1.1 \(status)\r\nContent-Type: \(mime)\r\nContent-Length: \(payload.count)\r\nConnection: close\r\n\r\n".utf8)
            response.append(payload)
            connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
        }
    }
    func stop() { listener.cancel(); queue.async { [self] in connections.forEach { $0.cancel() }; connections.removeAll() } }
}
