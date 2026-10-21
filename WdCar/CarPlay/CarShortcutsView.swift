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
        gradient.colors = [CarUI.navy.cgColor, UIColor.black.cgColor]
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

        titleLabel.text = "المتصفح"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .right
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        collection.backgroundColor = .clear
        collection.semanticContentAttribute = .forceRightToLeft
        collection.dataSource = self
        collection.delegate = self
        collection.register(CarShortcutCell.self, forCellWithReuseIdentifier: CarShortcutCell.id)
        collection.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collection)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            collection.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
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

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let available = max(1, collectionView.bounds.width - 32)
        let columns = max(1, min(5, Int((available + 10) / 160)))
        let width = (available - CGFloat(columns - 1) * 10) / CGFloat(columns)
        return CGSize(width: width, height: max(100, min(145, width * 0.64)))
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let size = self.collectionView(collectionView, layout: layout, sizeForItemAt: IndexPath(item: 0, section: 0))
        let columns = max(1, min(5, Int((max(1, collectionView.bounds.width - 32) + 10) / 160)))
        let rows = Int(ceil(Double(items.count) / Double(columns)))
        let height = CGFloat(rows) * size.height + CGFloat(max(0, rows - 1)) * 14
        return UIEdgeInsets(top: max(8, (collectionView.bounds.height - height) / 2), left: 16, bottom: 16, right: 16)
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

private final class CarShortcutCell: UICollectionViewCell {
    static let id = "CarShortcutCell"

    private let tile = UIView()
    private let sheen = CAGradientLayer()
    private let iconView = UIImageView()
    private let letterLabel = UILabel()
    private let nameLabel = UILabel()
    private var currentID: UUID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        tile.layer.cornerRadius = 16
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
        CarUI.pin(iconView, to: tile, insets: UIEdgeInsets(top: 12, left: 24, bottom: 38, right: 24))

        letterLabel.font = .systemFont(ofSize: 28, weight: .bold)
        letterLabel.textColor = .white
        letterLabel.textAlignment = .center
        tile.addSubview(letterLabel)
        CarUI.pin(letterLabel, to: tile)

        nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.7
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            tile.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            tile.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            tile.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tile.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tile.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: tile.bottomAnchor, constant: -12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        sheen.frame = tile.bounds
    }

    func configure(_ item: SiteShortcut) {
        currentID = item.id
        tile.backgroundColor = UIColor(hex: item.colorHex).withAlphaComponent(0.12)
        nameLabel.text = item.url.host?.contains("rain.ae") == true ? "طقس الإمارات · Rain.ae" : item.name
        letterLabel.text = String(item.name.prefix(1))
        letterLabel.isHidden = false
        iconView.image = item.iconURL == nil && item.url.host?.contains("rain.ae") == true ? UIImage(systemName: "cloud.sun.fill") : nil
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
