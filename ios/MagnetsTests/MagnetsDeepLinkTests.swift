import XCTest
@testable import Magnets

final class MagnetsDeepLinkTests: XCTestCase {
    func testParsesHomeURL() throws {
        let url = try XCTUnwrap(URL(string: "magnets://home"))

        XCTAssertEqual(MagnetsDeepLink(url: url), .home)
    }

    func testParsesMagnetURLWithInviteCode() throws {
        let magnetID = try XCTUnwrap(UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000"))
        let url = try XCTUnwrap(URL(string: "magnets://magnet/\(magnetID.uuidString)?invite=CODE"))

        XCTAssertEqual(
            MagnetsDeepLink(url: url),
            .magnet(id: magnetID, inviteCode: "CODE")
        )
    }

    func testParsesJoinURL() throws {
        let url = try XCTUnwrap(URL(string: "magnets://join/ABCD1234"))

        XCTAssertEqual(MagnetsDeepLink(url: url), .join(inviteCode: "ABCD1234"))
    }

    func testInvalidURLsReturnNil() throws {
        let invalidURLs = [
            "magnets://magnet",
            "magnets://magnet/not-a-uuid",
            "magnets://join",
            "magnets://unknown/path",
            "https://example.com/magnet/123",
        ]

        for rawURL in invalidURLs {
            let url = try XCTUnwrap(URL(string: rawURL))
            XCTAssertNil(MagnetsDeepLink(url: url), "Expected nil for \(rawURL)")
        }
    }

    func testRoundTripPreservesDeepLink() throws {
        let magnetID = try XCTUnwrap(UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000"))
        let deepLinks: [MagnetsDeepLink] = [
            .home,
            .magnet(id: magnetID, inviteCode: "CODE"),
            .join(inviteCode: "ABCD1234"),
        ]

        for deepLink in deepLinks {
            let reparsed = try XCTUnwrap(MagnetsDeepLink(url: deepLink.url))
            XCTAssertEqual(reparsed, deepLink)
        }
    }
}
