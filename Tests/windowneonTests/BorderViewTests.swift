import XCTest
import SnapshotTesting
@testable import windowneon

final class BorderViewTests: XCTestCase {
    override func setUp() {
        super.setUp()
        HighlightWindow.borderColor2 = nil
        HighlightWindow.borderWidth = 3
        HighlightWindow.cornerRadius = 10
        HighlightWindow.ticksEnabled = false
    }

    func testBorderColorIsRendered() {
        HighlightWindow.borderColor = .systemRed

        let view = BorderView()
        view.frame = NSRect(x: 0, y: 0, width: 200, height: 150)

        assertSnapshot(of: view, as: .image)
    }
}
