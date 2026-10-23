import XCTest
@testable import WdCar

final class DiagnosticLogTests: XCTestCase {
    private func temporaryLog() -> (DiagnosticLog, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("WudCar-DiagnosticLog-\(UUID().uuidString).txt")
        return (DiagnosticLog(fileURL: url), url)
    }

    func testEntriesPersistAcrossInstances() throws {
        let (log, url) = temporaryLog()
        defer { try? FileManager.default.removeItem(at: url) }
        log.append(category: "test", message: "first")
        log.append(category: "CarPlay", message: "second")
        let reopened = DiagnosticLog(fileURL: url)
        XCTAssertEqual(reopened.lineCount, 2)
        XCTAssertTrue(reopened.currentLines[0].contains("test\tfirst"))
        XCTAssertTrue(reopened.currentLines[1].contains("CarPlay\tsecond"))
    }

    func testLogRetainsOnlyLastFiveThousandLines() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("WudCar-DiagnosticLimit-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        let log = DiagnosticLog(fileURL: url, maximumLines: 5_000)
        for index in 0..<5_005 { log.append(category: "test", message: "line-\(index)") }
        XCTAssertEqual(log.lineCount, 5_000)
        XCTAssertTrue(log.currentLines.first?.contains("line-5") == true)
        XCTAssertFalse(log.currentLines.first?.contains("line-4") == true)
        XCTAssertTrue(log.currentLines.last?.contains("line-5004") == true)
        XCTAssertEqual(DiagnosticLog(fileURL: url, maximumLines: 5_000).lineCount, 5_000)
    }

    func testCredentialRedactionCoversURLUserInfoPathAndQuery() {
        let input = "https://alice:secret@example.test/live/channelUser/channelPass/123.m3u8?username=login&password=pw"
        let output = DiagnosticLog.redact(input)
        XCTAssertFalse(output.contains("alice"))
        XCTAssertFalse(output.contains("secret"))
        XCTAssertFalse(output.contains("channelUser"))
        XCTAssertFalse(output.contains("channelPass"))
        XCTAssertFalse(output.contains("login"))
        XCTAssertFalse(output.contains("pw"))
        XCTAssertTrue(output.contains("***"))
    }
}
