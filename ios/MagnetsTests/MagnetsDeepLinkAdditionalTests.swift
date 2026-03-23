import Foundation
import Testing
@testable import Magnets

struct MagnetsDeepLinkAdditionalTests {
    @Test
    func parsesHTTPSMagnetLinkWithInvite() throws {
        let magnetID = try #require(UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000"))
        let url = try #require(URL(string: "https://example.com/magnet/\(magnetID.uuidString.lowercased())?invite=CODE"))

        #expect(MagnetsDeepLink(url: url) == .magnet(id: magnetID, inviteCode: "CODE"))
    }

    @Test
    func parsesHTTPSJoinLinkWithCodeQuery() throws {
        let url = try #require(URL(string: "https://example.com/join?code=ABCD1234"))

        #expect(MagnetsDeepLink(url: url) == .join(inviteCode: "ABCD1234"))
    }
}
