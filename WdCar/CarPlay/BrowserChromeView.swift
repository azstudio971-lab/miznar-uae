import UIKit

/// Compact visuals with 44-point native hit regions while the transient bar is visible.
/// The extra 24 points overlap the page only while the bar is shown (six seconds).
final class BrowserChromeView: UIView {
    weak var toolbar: UIStackView?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let normal = super.hitTest(point, with: event)
        guard let toolbar, !toolbar.isHidden, !isHidden, isUserInteractionEnabled else { return normal }
        // Panels/overlays above the browser must retain priority.
        if let normal, normal.isInsideControl { return normal }
        let bar = toolbar.convert(toolbar.bounds, to: self)
        guard point.y >= bar.minY, point.y < bar.minY + 44 else { return normal }
        for case let button as UIButton in toolbar.arrangedSubviews where button.isEnabled && !button.isHidden {
            let rect = button.convert(button.bounds, to: self)
            if point.x >= rect.minX && point.x <= rect.maxX { return button }
        }
        return normal
    }
}
