import UIKit

/// Explicit symbol geometry avoids UIKit scaling a configured image beyond a 20pt bar.
final class CompactToolbarButton: UIButton {
    let symbolView: UIImageView
    private let countLabel = UILabel()
    var count: Int? { didSet { countLabel.text = count.map { String($0) }; countLabel.isHidden = count == nil } }

    init(_ symbol: String) {
        symbolView = UIImageView(image: UIImage(systemName: symbol))
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = CarUI.chip
        config.cornerStyle = .capsule
        config.contentInsets = .zero
        super.init(frame: .zero)
        configuration = config
        clipsToBounds = true
        symbolView.contentMode = .scaleAspectFit
        symbolView.tintColor = .white
        symbolView.preferredSymbolConfiguration = .init(pointSize: 11, weight: .semibold)
        symbolView.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = .systemFont(ofSize: 9, weight: .bold)
        countLabel.textColor = .white
        countLabel.isHidden = true
        let row = UIStackView(arrangedSubviews: [countLabel, symbolView])
        row.spacing = 3
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            symbolView.widthAnchor.constraint(equalToConstant: 12),
            symbolView.heightAnchor.constraint(equalToConstant: 12),
            row.centerXAnchor.constraint(equalTo: centerXAnchor),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            row.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
            row.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
            row.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 3),
            row.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -3)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
