import CoreGraphics
import Testing
@testable import IRecorderCore

@Test func centersWhenAlmostOffScreen() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let hidden = CGRect(x: 100, y: -500, width: 400, height: 560) // mostly below dock
    let fixed = WindowFrameClamp.ensureVisible(frame: hidden, screenVisible: screen)
    #expect(abs(fixed.midX - screen.midX) < 1)
    #expect(abs(fixed.midY - screen.midY) < 1)
    #expect(fixed.size == hidden.size)
}

@Test func clampsPartiallyOffRightEdge() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let frame = CGRect(x: 1300, y: 200, width: 400, height: 560)
    let fixed = WindowFrameClamp.ensureVisible(frame: frame, screenVisible: screen)
    #expect(fixed.maxX <= screen.maxX + 0.5)
    #expect(fixed.minY >= screen.minY - 0.5)
    #expect(fixed.width == 400)
}

@Test func leavesFullyVisibleFrameAlone() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let frame = CGRect(x: 200, y: 200, width: 400, height: 560)
    let fixed = WindowFrameClamp.ensureVisible(frame: frame, screenVisible: screen)
    #expect(fixed == frame)
}

@Test func nearAnchorPlacesBelowRightOfCursor() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let size = CGSize(width: 480, height: 420)
    let anchor = CGPoint(x: 400, y: 600)
    let frame = WindowFrameClamp.nearAnchor(anchor: anchor, size: size, screenVisible: screen, gap: 8)
    #expect(abs(frame.minX - (anchor.x + 8)) < 0.5)
    #expect(abs(frame.maxY - (anchor.y - 8)) < 0.5)
    #expect(frame.size == size)
}

@Test func nearAnchorFlipsAboveWhenTooLow() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let size = CGSize(width: 480, height: 420)
    let anchor = CGPoint(x: 400, y: 50)
    let frame = WindowFrameClamp.nearAnchor(anchor: anchor, size: size, screenVisible: screen, gap: 8)
    #expect(frame.minY >= screen.minY - 0.5)
    #expect(abs(frame.minY - (anchor.y + 8)) < 0.5 || frame.minY > anchor.y)
}

@Test func nearAnchorFlipsLeftWhenTooFarRight() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let size = CGSize(width: 480, height: 420)
    let anchor = CGPoint(x: 1400, y: 500)
    let frame = WindowFrameClamp.nearAnchor(anchor: anchor, size: size, screenVisible: screen, gap: 8)
    #expect(frame.maxX <= screen.maxX + 0.5)
    #expect(frame.minX < anchor.x)
}
