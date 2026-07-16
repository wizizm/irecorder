import CoreGraphics
import Foundation

public enum WindowFrameClamp {
    /// Keep `frame` on-screen. If less than `minVisibleFraction` of the window is visible, center it;
    /// otherwise clamp edges (avoids pinning a settings window to the dock edge).
    public static func ensureVisible(
        frame: CGRect,
        screenVisible: CGRect,
        minVisibleFraction: CGFloat = 0.35
    ) -> CGRect {
        guard !screenVisible.isNull, !screenVisible.isEmpty, frame.width > 0, frame.height > 0 else {
            return frame
        }

        let intersection = frame.intersection(screenVisible)
        let windowArea = frame.width * frame.height
        let visibleArea = intersection.isNull ? 0 : intersection.width * intersection.height
        let barelyVisible = windowArea <= 0 || visibleArea / windowArea < minVisibleFraction

        var result = frame
        if barelyVisible {
            result.origin.x = screenVisible.midX - frame.width / 2
            result.origin.y = screenVisible.midY - frame.height / 2
        }

        if result.maxX > screenVisible.maxX {
            result.origin.x = screenVisible.maxX - result.width
        }
        if result.minX < screenVisible.minX {
            result.origin.x = screenVisible.minX
        }
        if result.maxY > screenVisible.maxY {
            result.origin.y = screenVisible.maxY - result.height
        }
        if result.minY < screenVisible.minY {
            result.origin.y = screenVisible.minY
        }
        return result
    }
}
