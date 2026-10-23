import XCTest
@testable import WdCar

final class Media222Tests: XCTestCase {
    func testSRTMultilineAndCommaTimes() {
        let cues = SubtitleParser.parse("1\n00:00:01,250 --> 00:00:03,500\nمرحبا\nWelcome\n\n2\n00:00:04,000 --> 00:00:06,000\nNext\n")
        XCTAssertEqual(cues.count, 2)
        XCTAssertEqual(cues[0].start, 1.25)
        XCTAssertEqual(cues[0].text, "مرحبا\nWelcome")
    }
    func testVTTSettingsAndInvalidCues() {
        let cues = SubtitleParser.parse("WEBVTT\n\n00:01.000 --> 00:02.000 align:center\n<b>Caption</b>\n\n00:03.000 --> 00:02.000\nInvalid\n")
        XCTAssertEqual(cues, [.init(start: 1, end: 2, text: "Caption")])
        XCTAssertNil(SubtitleParser.timestamp("00:99:01"))
        XCTAssertNil(SubtitleParser.timestamp("NaN"))
    }
    func testLibraryMetadataDoesNotPersistNetworkSecrets() throws {
        let item = LibraryMedia(title: "Example", localFilename: nil, favorite: true, position: 12)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(LibraryMedia.self, from: data)
        XCTAssertEqual(decoded, item)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(object["url"])
        XCTAssertNil(object["password"])
    }
    func testExistingM3UParserKeepsGroupsAndRejectsNonHTTPEntries() throws {
        let text = "#EXTM3U\n#EXTINF:-1 group-title=\"News\",Channel\nhttps://example.test/live.m3u8\nfile:///etc/passwd\n"
        let entries = try M3UParser.parse(Data(text.utf8))
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].group, "News")
    }
}
