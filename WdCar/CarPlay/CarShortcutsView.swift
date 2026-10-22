import UIKit
import Combine

/// شبكة الاختصارات في السيارة (صفحة "المتصفح" الرئيسية)
final class CarShortcutsView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onSelect: ((SiteShortcut) -> Void)?

    private let gradient = CAGradientLayer()
    private let hint = UILabel()
    private let pattern = CAShapeLayer()
    private var items: [SiteShortcut] = []
    private let titleLabel = UILabel()
    private let collection: UICollectionView
    private var bag = Set<AnyCancellable>()

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 96, height: 104)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 14
        layout.sectionInset = UIEdgeInsets(top: 8, left: 16, bottom: 16, right: 16)
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)

        backgroundColor = CarUI.navy
        gradient.colors = [UIColor(hex: "#071526").cgColor, UIColor(hex: "#020711").cgColor]
        gradient.startPoint = .zero
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradient, at: 0)
        pattern.strokeColor = UIColor.white.withAlphaComponent(0.035).cgColor
        pattern.fillColor = UIColor.clear.cgColor
        pattern.lineWidth = 0.7
        layer.insertSublayer(pattern, above: gradient)
        hint.text = "لإظهار شريط التحكم العلوي أو العودة إلى الصفحة الرئيسية، اضغط على أقصى يسار الشاشة لإظهار زر (•••)، ثم اختر الإجراء المطلوب."
        hint.textColor = UIColor(white: 0.85, alpha: 1)
        hint.font = .systemFont(ofSize: 12)
        hint.numberOfLines = 0
        hint.textAlignment = .center
        hint.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hint)
        semanticContentAttribute = .forceRightToLeft

        titleLabel.accessibilityIdentifier = "car.browser.shortcuts.title"
        titleLabel.text = "المتصفح"
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .right
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        collection.backgroundColor = .clear
        collection.semanticContentAttribute = .forceLeftToRight
        collection.dataSource = self
        collection.delegate = self
        collection.register(CarShortcutCell.self, forCellWithReuseIdentifier: CarShortcutCell.id)
        collection.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collection)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            collection.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            collection.leadingAnchor.constraint(equalTo: leadingAnchor),
            collection.trailingAnchor.constraint(equalTo: trailingAnchor),
            collection.bottomAnchor.constraint(equalTo: hint.topAnchor, constant: -6),
            hint.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            hint.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            hint.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])

        ShortcutStore.shared.$shortcuts
            .receive(on: RunLoop.main)
            .sink { [weak self] list in
                self?.items = list
                self?.collection.reloadData()
            }
            .store(in: &bag)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        pattern.frame = bounds
        let path = UIBezierPath()
        for offset in stride(from: -bounds.height, through: bounds.width, by: 36) {
            path.move(to: CGPoint(x: offset, y: 0))
            path.addLine(to: CGPoint(x: offset + bounds.height, y: bounds.height))
        }
        pattern.path = path.cgPath
        collection.collectionViewLayout.invalidateLayout()
    }

    static func gridMetrics(for size: CGSize) -> (columns: Int, item: CGSize, sideInset: CGFloat) {
        let available = max(1, size.width - 32)
        let capacity = max(1, Int((available + 10) / 114))
        let wide = size.width / max(1, size.height) >= 1.65
        let desired = wide ? 8 : 5
        let columns = min(desired, capacity)
        let width = min(156, (available - CGFloat(columns - 1) * 10) / CGFloat(columns))
        let totalWidth = CGFloat(columns) * width + CGFloat(columns - 1) * 10
        return (columns, CGSize(width: width, height: width / 1.55), max(16, (size.width - totalWidth) / 2))
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        Self.gridMetrics(for: bounds.size).item
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let metrics = Self.gridMetrics(for: bounds.size)
        return UIEdgeInsets(top: 8, left: metrics.sideInset, bottom: 16, right: metrics.sideInset)
    }

    /// Activate an app-owned shortcut from the phone touchpad without synthetic UIKit touches.
    @discardableResult
    func activateShortcut(at point: CGPoint) -> Bool {
        let pointInCollection = collection.convert(point, from: self)
        guard let index = collection.indexPathForItem(at: pointInCollection), items.indices.contains(index.item) else { return false }
        onSelect?(items[index.item])
        return true
    }

    func scrollFromPhone(_ delta: CGPoint) {
        let maxY = max(0, collection.contentSize.height - collection.bounds.height)
        let nextY = min(maxY, max(0, collection.contentOffset.y + delta.y * collection.bounds.height))
        collection.setContentOffset(CGPoint(x: 0, y: nextY), animated: true)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CarShortcutCell.id, for: indexPath) as! CarShortcutCell
        cell.configure(items[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelect?(items[indexPath.item])
    }
}

final class CarShortcutCell: UICollectionViewCell {
    static let id = "CarShortcutCell"

    private let tile = UIView()
    private let sheen = CAGradientLayer()
    private let iconView = UIImageView()
    private let letterLabel = UILabel()
    private let nameLabel = UILabel()
    private var currentID: UUID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        tile.layer.cornerRadius = 14
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.22
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 3)
        tile.layer.cornerCurve = .continuous
        tile.clipsToBounds = true
        sheen.colors = [UIColor.white.withAlphaComponent(0.12).cgColor, UIColor.clear.cgColor, UIColor.white.withAlphaComponent(0.025).cgColor]
        sheen.startPoint = .zero
        sheen.endPoint = CGPoint(x: 1, y: 1)
        tile.layer.addSublayer(sheen)
        tile.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        tile.layer.borderWidth = 1
        tile.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
        tile.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tile)

        iconView.contentMode = .scaleAspectFit
        tile.addSubview(iconView)
        CarUI.pin(iconView, to: tile, insets: UIEdgeInsets(top: 10, left: 22, bottom: 29, right: 22))

        letterLabel.font = .systemFont(ofSize: 28, weight: .bold)
        letterLabel.textColor = .white
        letterLabel.textAlignment = .center
        tile.addSubview(letterLabel)
        CarUI.pin(letterLabel, to: tile, insets: UIEdgeInsets(top: 8, left: 8, bottom: 28, right: 8))

        nameLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        nameLabel.numberOfLines = 2
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.85
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            tile.topAnchor.constraint(equalTo: contentView.topAnchor),
            tile.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            tile.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tile.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tile.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: tile.bottomAnchor, constant: -5),
            nameLabel.heightAnchor.constraint(equalToConstant: 24),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        sheen.frame = tile.bounds
    }

    func configure(_ item: SiteShortcut) {
        currentID = item.id
        tile.backgroundColor = UIColor(hex: item.colorHex)
        let host = item.url.host ?? ""
        let light = ["www.google.com", "www.youtubekids.com", "mail.google.com"].contains(host)
        nameLabel.textColor = light ? UIColor(hex: "#101724") : .white
        letterLabel.textColor = nameLabel.textColor
        sheen.colors = host.contains("instagram.com")
            ? [UIColor(hex: "#6621D8").cgColor, UIColor.clear.cgColor, UIColor(hex: "#FF8C1C").cgColor]
            : [UIColor.white.withAlphaComponent(0.12).cgColor, UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.25).cgColor]
        nameLabel.text = item.url.host?.contains("rain.ae") == true ? "UAE Weather" : item.name
        letterLabel.text = ["TOD", "STARZPLAY"].contains(item.name) ? item.name : String(item.name.prefix(1))
        letterLabel.font = .systemFont(ofSize: item.name == "STARZPLAY" ? 14 : 24, weight: .bold)
        letterLabel.isHidden = false
        accessibilityLabel = item.name
        accessibilityIdentifier = "shortcut.\(ShortcutCatalog.identity(item.url))"
        iconView.image = ShortcutArtwork.bundled(for: item) ?? (item.iconURL == nil && item.url.host?.contains("rain.ae") == true ? UIImage(systemName: "cloud.sun.fill") : nil)
        iconView.tintColor = .systemYellow
        if iconView.image != nil { letterLabel.isHidden = true; return }
        ImageLoader.shared.load(item.iconURL ?? Favicon.url(for: item.url)) { [weak self] image in
            guard let self, self.currentID == item.id else { return }
            self.iconView.image = image
            self.letterLabel.isHidden = image != nil
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        tile.layer.borderColor = (isFocused ? UIColor.systemCyan : UIColor.white.withAlphaComponent(0.22)).cgColor
        tile.layer.borderWidth = isFocused ? 3 : 1
    }

    override var isHighlighted: Bool {
        didSet { tile.alpha = isHighlighted ? 0.6 : 1 }
    }
}
