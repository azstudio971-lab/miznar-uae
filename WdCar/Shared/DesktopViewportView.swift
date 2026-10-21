import UIKit
import WebKit
import Combine

/// Desktop request, WebKit page zoom and display fitting are independent.
/// Keep the layout viewport wide enough for desktop breakpoints, then fit the
/// native view uniformly. Never rewrite a site's viewport or CSS.
final class DesktopViewportView: UIView {
    static let desktopWidth: CGFloat = 1280
    let session: TabSession
    private var modeObservation: AnyCancellable?

    init(session: TabSession) {
        self.session = session
        super.init(frame: .zero)
        backgroundColor = .black
        clipsToBounds = true
        let web = session.webView
        web.removeFromSuperview()
        web.translatesAutoresizingMaskIntoConstraints = true
        web.autoresizingMask = []
        addSubview(web)
        modeObservation = session.$isDesktopMode.sink { [weak self] desktop in
            self?.layoutWebView(desktop: desktop)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutWebView(desktop: session.isDesktopMode)
    }

    private func layoutWebView(desktop: Bool) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let width = desktop ? max(Self.desktopWidth, bounds.width) : bounds.width
        let fit = bounds.width / width
        let web = session.webView
        // frame is undefined with a nonidentity transform: set bounds/center.
        web.bounds = CGRect(x: 0, y: 0, width: width, height: bounds.height / fit)
        web.center = CGPoint(x: bounds.midX, y: bounds.midY)
        web.transform = CGAffineTransform(scaleX: fit, y: fit)
    }
}
