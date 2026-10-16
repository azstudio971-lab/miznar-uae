import UIKit

/// ألوان وأزرار واجهة السيارة
enum CarUI {
    static let accent = UIColor(red: 254/255, green: 177/255, blue: 59/255, alpha: 1)
    static let navy = UIColor(red: 1/255, green: 55/255, blue: 72/255, alpha: 1)
    static let chip = UIColor(white: 0.15, alpha: 1)
    static let panel = UIColor(white: 0.10, alpha: 1)

    static func iconButton(_ symbol: String, size: CGFloat = 17, background: UIColor = chip) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = background
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.image = UIImage(systemName: symbol,
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .semibold))
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 11, bottom: 8, trailing: 11)
        return UIButton(configuration: config)
    }

    static func textButton(_ title: String, size: CGFloat = 17, background: UIColor = chip) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = background
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.attributedTitle = AttributedString(title, attributes: AttributeContainer([
            .font: UIFont.systemFont(ofSize: size, weight: .semibold)
        ]))
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        return UIButton(configuration: config)
    }

    static func setTitle(_ button: UIButton, _ title: String, size: CGFloat = 17) {
        var config = button.configuration ?? .filled()
        config.attributedTitle = AttributedString(title, attributes: AttributeContainer([
            .font: UIFont.systemFont(ofSize: size, weight: .semibold)
        ]))
        button.configuration = config
    }

    static func setSymbol(_ button: UIButton, _ symbol: String, size: CGFloat = 17) {
        var config = button.configuration ?? .filled()
        config.image = UIImage(systemName: symbol,
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .semibold))
        button.configuration = config
    }

    static func pin(_ view: UIView, to container: UIView, insets: UIEdgeInsets = .zero) {
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: insets.top),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -insets.bottom),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: insets.left),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -insets.right)
        ])
    }

    static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

/// UILabel بحواف داخلية (للتنبيهات القصيرة)
final class PaddingLabel: UILabel {
    var insets = UIEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}

extension UIView {
    /// هل هذا العنصر داخل زر؟ (لتجاهل لمسات الأزرار في إيماءات الإخفاء/الإظهار)
    var isInsideControl: Bool {
        var view: UIView? = self
        while let current = view {
            if current is UIControl { return true }
            view = current.superview
        }
        return false
    }
}
