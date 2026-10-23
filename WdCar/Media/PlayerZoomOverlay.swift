import UIKit
import AVFoundation
import AVKit

final class PlayerZoomOverlay: UIView {
    private let video = AVPlayerLayer()
    private var zoom: CGFloat = 1
    private var actual = false
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .black; layer.addSublayer(video); isUserInteractionEnabled = false }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(_ player: AVPlayer, zoom: Double, actual: Bool) {
        video.player = player; self.zoom = CGFloat(zoom); self.actual = actual
        video.videoGravity = PlayerPreferences.gravity; setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews(); clipsToBounds = true
        CATransaction.begin(); CATransaction.setDisableActions(true)
        let presentation = video.player?.currentItem?.presentationSize ?? .zero
        let size = actual && presentation.width > 0 ? CGSize(width: presentation.width / traitCollection.displayScale, height: presentation.height / traitCollection.displayScale) : bounds.size
        video.bounds = CGRect(origin: .zero, size: CGSize(width: size.width * zoom, height: size.height * zoom))
        video.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()
    }
    static func apply(to controller: AVPlayerViewController) {
        guard let container = controller.contentOverlayView else { return }
        let zoom = PlayerPreferences.number("videoZoom", 1)
        let actual = PlayerPreferences.flag("actualSize", false)
        let old = container.viewWithTag(30301) as? PlayerZoomOverlay
        guard abs(zoom - 1) > 0.001 || actual else { old?.removeFromSuperview(); return }
        let overlay = old ?? PlayerZoomOverlay(frame: container.bounds)
        overlay.tag = 30301; overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if overlay.superview == nil { container.addSubview(overlay) }
        overlay.configure(PlaybackManager.shared.player, zoom: zoom, actual: actual)
    }
}
