import UIKit
import Combine

/// Adaptive, compact primary sites followed by the user's favorites.
final class CarShortcutsView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onSelect: ((SiteShortcut) -> Void)?
    private var groups: [[SiteShortcut]] = [[], []]
    private let collection: UICollectionView
    private var bag = Set<AnyCancellable>()

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 4
        layout.sectionInset = UIEdgeInsets(top: 2, left: 12, bottom: 8, right: 12)
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        backgroundColor = .black
        collection.backgroundColor = .clear
        collection.semanticContentAttribute = WDSettings.carLanguage == "ar" ? .forceRightToLeft : .forceLeftToRight
        collection.dataSource = self
        collection.delegate = self
        collection.register(CarShortcutCell.self, forCellWithReuseIdentifier: CarShortcutCell.id)
        collection.register(CarShortcutHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "header")
        addSubview(collection)
        CarUI.pin(collection, to: self)
        ShortcutStore.shared.$shortcuts.receive(on: RunLoop.main).sink { [weak self] list in
            self?.groups = [list.filter { ShortcutStore.isBuiltIn($0) }, list.filter { !ShortcutStore.isBuiltIn($0) }]
            self?.collection.reloadData()
        }.store(in: &bag)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() { super.layoutSubviews(); collection.collectionViewLayout.invalidateLayout() }
    func numberOfSections(in collectionView: UICollectionView) -> Int { 2 }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { groups[section].count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CarShortcutCell.id, for: indexPath) as! CarShortcutCell
        cell.configure(groups[indexPath.section][indexPath.item]); return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) { onSelect?(groups[indexPath.section][indexPath.item]) }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let available = max(1, collectionView.bounds.width - 24)
        let columns = max(4, min(8, Int(available / 70)))
        return CGSize(width: floor((available - CGFloat(columns - 1) * 4) / CGFloat(columns)), height: 60)
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        CGSize(width: collectionView.bounds.width, height: groups[section].isEmpty ? 0 : 22)
    }
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath) as! CarShortcutHeader
        header.label.text = indexPath.section == 0 ? carTr("المواقع الرئيسية", "Main sites") : carTr("المفضلة", "Favorites")
        return header
    }
}
private final class CarShortcutHeader: UICollectionReusableView {
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 12, weight: .semibold); label.textColor = .lightGray
        label.textAlignment = WDSettings.carLanguage == "ar" ? .right : .left
        addSubview(label); CarUI.pin(label, to: self, insets: UIEdgeInsets(top: 2, left: 14, bottom: 2, right: 14))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class CarShortcutCell: UICollectionViewCell {
    static let id = "CarShortcutCell"

    private let tile = UIView()
    private let iconView = UIImageView()
    private let letterLabel = UILabel()
    private let nameLabel = UILabel()
    private var currentID: UUID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        tile.layer.cornerRadius = 10
        tile.layer.cornerCurve = .continuous
        tile.clipsToBounds = true
        tile.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tile)

        iconView.contentMode = .scaleAspectFit
        tile.addSubview(iconView)
        CarUI.pin(iconView, to: tile, insets: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))

        letterLabel.font = .systemFont(ofSize: 21, weight: .bold)
        letterLabel.textColor = .white
        letterLabel.textAlignment = .center
        tile.addSubview(letterLabel)
        CarUI.pin(letterLabel, to: tile)

        nameLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.7
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            tile.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            tile.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            tile.widthAnchor.constraint(equalToConstant: 40),
            tile.heightAnchor.constraint(equalToConstant: 40),
            nameLabel.topAnchor.constraint(equalTo: tile.bottomAnchor, constant: 3),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ item: SiteShortcut) {
        accessibilityIdentifier = "shortcut." + item.name
        isAccessibilityElement = true
        accessibilityLabel = item.name
        accessibilityTraits = .button
        currentID = item.id
        tile.backgroundColor = UIColor(hex: item.colorHex)
        nameLabel.text = item.name
        letterLabel.text = String(item.name.prefix(1))
        letterLabel.isHidden = false
        iconView.image = nil
        ImageLoader.shared.load(Favicon.url(for: item.url)) { [weak self] image in
            guard let self, self.currentID == item.id else { return }
            self.iconView.image = image
            self.letterLabel.isHidden = image != nil
        }
    }

    override var isHighlighted: Bool {
        didSet { tile.alpha = isHighlighted ? 0.6 : 1 }
    }
}
