import UIKit
import Combine

/// شاشة "علامات التبويب" في السيارة: بطاقات أفقية + ✓ + العداد + زر إضافة
final class CarTabsPanel: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    var onSelect: ((UUID) -> Void)?
    var onNewTab: (() -> Void)?
    var onDone: (() -> Void)?

    private let store: TabStore
    private var tabs: [BrowserTab] = []
    private let collection: UICollectionView
    private let countLabel = UILabel()
    private var bag = Set<AnyCancellable>()

    init(store: TabStore) {
        self.store = store
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 230, height: 190)
        layout.minimumLineSpacing = 18
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 0.09, alpha: 0.98)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        let title = UILabel()
        title.text = "علامات التبويب"
        title.font = .systemFont(ofSize: 26, weight: .bold)
        title.textColor = .white
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)

        collection.backgroundColor = .clear
        collection.semanticContentAttribute = .forceRightToLeft
        collection.showsHorizontalScrollIndicator = false
        collection.dataSource = self
        collection.delegate = self
        collection.register(CarTabCell.self, forCellWithReuseIdentifier: CarTabCell.id)
        collection.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collection)

        let doneButton = CarUI.iconButton("checkmark", size: 24, background: CarUI.accent)
        doneButton.addAction(UIAction { [weak self] _ in self?.onDone?() }, for: .touchUpInside)
        let plusButton = CarUI.iconButton("plus", size: 24)
        plusButton.addAction(UIAction { [weak self] _ in self?.onNewTab?() }, for: .touchUpInside)

        countLabel.font = .monospacedDigitSystemFont(ofSize: 22, weight: .medium)
        countLabel.textColor = .lightGray
        countLabel.textAlignment = .center

        [doneButton, plusButton, countLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            title.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -24),

            collection.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 14),
            collection.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            collection.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
            collection.heightAnchor.constraint(equalToConstant: 200),

            doneButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 24),
            doneButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -14),
            doneButton.widthAnchor.constraint(equalToConstant: 62),
            doneButton.heightAnchor.constraint(equalToConstant: 62),

            plusButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -24),
            plusButton.centerYAnchor.constraint(equalTo: doneButton.centerYAnchor),
            plusButton.widthAnchor.constraint(equalToConstant: 62),
            plusButton.heightAnchor.constraint(equalToConstant: 62),

            countLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            countLabel.centerYAnchor.constraint(equalTo: doneButton.centerYAnchor)
        ])

        store.$tabs
            .combineLatest(store.$activeID, store.$snapshots)
            .receive(on: RunLoop.main)
            .sink { [weak self] tabs, _, _ in
                guard let self else { return }
                self.tabs = tabs
                self.countLabel.text = self.store.countText
                self.collection.reloadData()
            }
            .store(in: &bag)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        tabs.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CarTabCell.id, for: indexPath) as! CarTabCell
        let tab = tabs[indexPath.item]
        cell.configure(tab: tab, snapshot: store.snapshots[tab.id], isActive: tab.id == store.activeID)
        cell.onClose = { [weak self] in self?.store.close(tab.id) }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelect?(tabs[indexPath.item].id)
    }
}

private final class CarTabCell: UICollectionViewCell {
    static let id = "CarTabCell"
    var onClose: (() -> Void)?

    private let card = UIView()
    private let imageView = UIImageView()
    private let placeholder = UIImageView(image: UIImage(systemName: "globe"))
    private let closeButton = CarUI.iconButton("xmark", size: 15, background: UIColor(white: 0, alpha: 0.65))
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        card.backgroundColor = .black
        card.layer.cornerRadius = 22
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        imageView.contentMode = .scaleAspectFill
        card.addSubview(imageView)
        CarUI.pin(imageView, to: card)

        placeholder.tintColor = .darkGray
        placeholder.contentMode = .scaleAspectFit
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(placeholder)

        closeButton.addAction(UIAction { [weak self] _ in self?.onClose?() }, for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(closeButton)

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.heightAnchor.constraint(equalToConstant: 150),
            placeholder.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            placeholder.widthAnchor.constraint(equalToConstant: 40),
            placeholder.heightAnchor.constraint(equalToConstant: 40),
            closeButton.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            closeButton.leftAnchor.constraint(equalTo: card.leftAnchor, constant: 8),
            titleLabel.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(tab: BrowserTab, snapshot: UIImage?, isActive: Bool) {
        imageView.image = snapshot
        placeholder.isHidden = snapshot != nil
        placeholder.image = UIImage(systemName: tab.url == nil ? "square.grid.2x2" : "globe")
        titleLabel.text = tab.url == nil ? "الرئيسية" : tab.displayTitle
        card.layer.borderWidth = isActive ? 3 : 1
        card.layer.borderColor = (isActive ? CarUI.accent : UIColor(white: 1, alpha: 0.1)).cgColor
    }
}
