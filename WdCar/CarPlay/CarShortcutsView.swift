import UIKit
import Combine

/// شبكة الاختصارات في السيارة (صفحة "المتصفح" الرئيسية)
final class CarShortcutsView: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    var onSelect: ((SiteShortcut) -> Void)?

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

        backgroundColor = .black
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
            collection.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        ShortcutStore.shared.$shortcuts
            .receive(on: RunLoop.main)
            .sink { [weak self] list in
                self?.items = list
                self?.collection.reloadData()
            }
            .store(in: &bag)
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
    private let iconView = UIImageView()
    private let letterLabel = UILabel()
    private let nameLabel = UILabel()
    private var currentID: UUID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        tile.layer.cornerRadius = 16
        tile.layer.cornerCurve = .continuous
        tile.clipsToBounds = true
        tile.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tile)

        iconView.contentMode = .scaleAspectFit
        tile.addSubview(iconView)
        CarUI.pin(iconView, to: tile, insets: UIEdgeInsets(top: 13, left: 13, bottom: 13, right: 13))

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
            tile.widthAnchor.constraint(equalToConstant: 64),
            tile.heightAnchor.constraint(equalToConstant: 64),
            nameLabel.topAnchor.constraint(equalTo: tile.bottomAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ item: SiteShortcut) {
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
