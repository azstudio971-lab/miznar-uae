import UIKit

/// كيبورد السيارة على الشاشة: عربي (مثل CarTV) وإنجليزي
final class CarKeyboardView: UIView {
    enum Layout { case arabic, english }

    var onInsert: ((String) -> Void)?
    var onDelete: (() -> Void)?
    var onDone: (() -> Void)?

    private(set) var layout: Layout
    private var shifted = false
    private let rowsStack = UIStackView()

    init(layout: Layout) {
        self.layout = layout
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 0.90, alpha: 1)
        layer.cornerRadius = 14
        semanticContentAttribute = .forceLeftToRight

        rowsStack.axis = .vertical
        rowsStack.spacing = 6
        rowsStack.distribution = .fillEqually
        rowsStack.semanticContentAttribute = .forceLeftToRight
        addSubview(rowsStack)
        CarUI.pin(rowsStack, to: self, insets: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
        rebuild()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setLayout(_ newLayout: Layout) {
        layout = newLayout
        shifted = false
        rebuild()
    }

    private func letterRows() -> [[String]] {
        func split(_ s: String) -> [String] { s.split(separator: " ").map(String.init) }
        switch layout {
        case .arabic:
            return [
                split("1 2 3 4 5 6 7 8 9 0"),
                split("ض ص ث ق ف غ ع ه خ ح ج"),
                split("ش س ي ب ل ا ت ن م ك ط"),
                split("ئ ء ؤ ر لا ى ة و ز ظ د")
            ]
        case .english:
            let rows = [
                split("1 2 3 4 5 6 7 8 9 0"),
                split("q w e r t y u i o p"),
                split("a s d f g h j k l"),
                split("z x c v b n m")
            ]
            return shifted ? rows.map { $0.map { $0.uppercased() } } : rows
        }
    }

    private func rebuild() {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let rows = letterRows()
        for (index, keys) in rows.enumerated() {
            let row = makeRow()
            row.distribution = .fillEqually
            if layout == .english, index == rows.count - 1 {
                let shift = specialKey(symbol: shifted ? "shift.fill" : "shift") { [weak self] in
                    guard let self else { return }
                    self.shifted.toggle()
                    self.rebuild()
                }
                row.addArrangedSubview(shift)
            }
            keys.forEach { key in
                row.addArrangedSubview(characterKey(key))
            }
            rowsStack.addArrangedSubview(row)
        }

        // الصف الأخير: @ . .com مسافة حذف تم
        let bottom = makeRow()
        let small: [UIButton] = [characterKey("@"), characterKey("."), characterKey(".com")]
        small.forEach { $0.widthAnchor.constraint(equalToConstant: 64).isActive = true; bottom.addArrangedSubview($0) }
        let space = characterKey(" ", title: layout == .arabic ? "مسافة" : "space")
        space.setContentHuggingPriority(.defaultLow, for: .horizontal)
        bottom.addArrangedSubview(space)
        let delete = specialKey(symbol: "delete.left") { [weak self] in self?.onDelete?() }
        delete.widthAnchor.constraint(equalToConstant: 76).isActive = true
        bottom.addArrangedSubview(delete)
        let done = specialKey(symbol: "magnifyingglass", tint: CarUI.accent) { [weak self] in self?.onDone?() }
        done.widthAnchor.constraint(equalToConstant: 90).isActive = true
        bottom.addArrangedSubview(done)
        rowsStack.addArrangedSubview(bottom)
    }

    private func makeRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 6
        row.distribution = .fill
        row.semanticContentAttribute = .forceLeftToRight
        return row
    }

    private func characterKey(_ value: String, title: String? = nil) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .white
        config.baseForegroundColor = .black
        config.background.cornerRadius = 8
        config.attributedTitle = AttributedString(title ?? value, attributes: AttributeContainer([
            .font: UIFont.systemFont(ofSize: value.count > 2 ? 16 : 22, weight: .regular)
        ]))
        config.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
        let button = UIButton(configuration: config)
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onInsert?(value)
            if self.shifted { self.shifted = false; self.rebuild() }
        }, for: .touchUpInside)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return button
    }

    private func specialKey(symbol: String, tint: UIColor = UIColor(white: 0.72, alpha: 1), action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = tint
        config.baseForegroundColor = tint == CarUI.accent ? .white : .black
        config.background.cornerRadius = 8
        config.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold))
        let button = UIButton(configuration: config)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }
}
