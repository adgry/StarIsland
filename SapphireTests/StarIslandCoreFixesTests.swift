import XCTest
@testable import Sapphire

final class StarIslandCoreFixesTests: XCTestCase {
    @MainActor
    func testUpdateRepositoryPointsToStarIsland() {
        XCTAssertEqual(UpdateChecker.updateRepository, "adgry/StarIsland")
        XCTAssertEqual(UpdateChecker.repositoryWebURL.absoluteString, "https://github.com/adgry/StarIsland")
    }

    func testSemVerOrderingHandlesMultiDigitMinorAndMajorUpgrade() {
        XCTAssertTrue(SapphireVersionOrdering.isNewer("2.0.0", than: "1.0.0"))
        XCTAssertTrue(SapphireVersionOrdering.isNewer("2.10.0", than: "2.2.0"))
        XCTAssertFalse(SapphireVersionOrdering.isNewer("2.0.0", than: "2.0.0"))
    }

    func testAutomationPermissionNeverAutoLaunchesMusicOrSpotify() {
        XCTAssertFalse(PermissionsManager.shouldAutoLaunchForAutomation(bundleIdentifier: "com.apple.Music"))
        XCTAssertFalse(PermissionsManager.shouldAutoLaunchForAutomation(bundleIdentifier: "com.spotify.client"))
        XCTAssertTrue(PermissionsManager.shouldAutoLaunchForAutomation(bundleIdentifier: "com.apple.systemevents"))
    }

    @MainActor
    func testHelperIdentifierMatchesStarIslandHelper() {
        XCTAssertEqual(HelperManager.shared.helperToolIdentifier, "com.adgry.starisland.helper")
    }
}
