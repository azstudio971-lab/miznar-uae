import UIKit
import Combine

/// شاشة الكتابة في السيارة (مثل CarTV):
/// إلغاء | حقل النص | بحث — ميكروفون كبير — العربية | لوحة المفاتيح | الهاتف
/// النص متزامن لحظياً مع "لوحة مفاتيح CarPlay" على الهاتف.
final class CarTextInputView: UIView {
    enum Mode { case webField, url }

    var onSubmit: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onLiveText: ((String) -> Void)?

    private let mode: Mode
    private let placeholder: String
    private(set) var text: String
    private var isArabic = WDSettings.carInputIsArabic
    private var keyboardShown = false
    private var listening = false
    private var bag = Set<AnyCancellable>()
    private let bridge = CarKeyboardBridge.shared

    private let textLabel = UILabel()
    private let clearButton = CarUI.iconButton("xmark", size: 13, background: UIColor(white: 0.3, alpha: 1))
    private let middle = UIView()
    private let micButton = UIButton(type: .system)
    private let hintLabel = UILabel()
    private let languageButton = CarUI.textButton("العربية", size: 18)
    private let keyboardButton = CarUI.textButton("لوحة المفاتيح", size: 18)
    private let phoneButton = CarUI.iconButton("iphone", size: 20)
    private lazy var keyboard: CarKeyboardView = {
        let view = CarKeyboardView(layout: isArabic ? .arabic : .english)
        view.onInsert = { [weak self] value in
            guard let self else { return }
            self.apply(self.text + value, toBridge: true)
        }
        view.onDelete = { [weak self] in
            guard let self, !self.text.isEmpty else { return }
            self.apply(String(self.text.dropLast()), toBridge: true)
        }
        view.onDone = { [weak self] in self?.bridge.submit() }
        return view
    }()

    init(mode: Mode, initialText: String, placeholder: String) {
        self.mode = mode
        self.text = initialText
        self.placeholder = placeholder.isEmpty
            ? (mode == .url ? "أدخل عنوان URL أو ابحث" : "اكتب هنا")
            : placeholder
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 0.04, alpha: 0.97)
        semanticContentAttribute = .forceLeftToRight
        build()
        render()
        bind()
        bridge.begin(initial: initialText, placeholder: self.placeholder)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: البناء

    private func build() {
        // الصف العلوي
        let cancelButton = CarUI.textButton("إلغاء", size: 20)
        cancelButton.addAction(UIAction { [weak self] _ in self?.bridge.cancel() }, for: .touchUpInside)

        let searchButton = CarUI.iconButton("magnifyingglass", size: 22, background: CarUI.accent)
        searchButton.addAction(UIAction { [weak self] _ in self?.bridge.submit() }, for: .touchUpInside)

        let field = UIView()
        field.backgroundColor = UIColor(white: 0.12, alpha: 1)
        field.layer.cornerRadius = 16
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor(white: 1, alpha: 0.12).cgColor
        textLabel.font = .systemFont(ofSize: 24, weight: .medium)
        textLabel.lineBreakMode = .byTruncatingHead
        clearButton.addAction(UIAction { [weak self] _ in self?.apply("", toBridge: true) }, for: .touchUpInside)
        [textLabel, clearButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; field.addSubview($0) }
        NSLayoutConstraint.activate([
            textLabel.leadingAnchor.constraint(equalTo: field.leadingAnchor, constant: 16),
            textLabel.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            textLabel.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -8),
            clearButton.trailingAnchor.constraint(equalTo: field.trailingAnchor, constant: -10),
            clearButton.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 34),
            clearButton.heightAnchor.constraint(equalToConstant: 34)
        ])

        let top = UIStackView(arrangedSubviews: [cancelButton, field, searchButton])
        top.axis = .horizontal
        top.spacing = 10
        top.semanticContentAttribute = .forceLeftToRight
        cancelButton.setContentHuggingPriority(.required, for: .horizontal)
        searchButton.setContentHuggingPriority(.required, for: .horizontal)
        searchButton.widthAnchor.constraint(equalToConstant: 80).isActive = true

        // الوسط: الميكروفون + التلميح، أو الكيبورد
        var micConfig = UIButton.Configuration.filled()
        micConfig.baseBackgroundColor = CarUI.accent
        micConfig.baseForegroundColor = .white
        micConfig.cornerStyle = .capsule
        micConfig.image = UIImage(systemName: "mic.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 40, weight: .medium))
        micButton.configuration = micConfig
        micButton.addAction(UIAction { [weak self] _ in self?.toggleListening() }, for: .touchUpInside)

        hintLabel.text = "افتح ود كار على iPhone للكتابة، أو اضغط الميكروفون وتكلّم."
        hintLabel.font = .systemFont(ofSize: 17, weight: .medium)
        hintLabel.textColor = .lightGray
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 2

        [micButton, hintLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; middle.addSubview($0) }
        NSLayoutConstraint.activate([
            micButton.centerXAnchor.constraint(equalTo: middle.centerXAnchor),
            micButton.centerYAnchor.constraint(equalTo: middle.centerYAnchor, constant: -16),
            micButton.widthAnchor.constraint(equalToConstant: 120),
            micButton.heightAnchor.constraint(equalToConstant: 120),
            hintLabel.topAnchor.constraint(equalTo: micButton.bottomAnchor, constant: 14),
            hintLabel.leadingAnchor.constraint(equalTo: middle.leadingAnchor, constant: 20),
            hintLabel.trailingAnchor.constraint(equalTo: middle.trailingAnchor, constant: -20)
        ])

        // الصف السفلي
        languageButton.addAction(UIAction { [weak self] _ in self?.toggleLanguage() }, for: .touchUpInside)
        keyboardButton.addAction(UIAction { [weak self] _ in self?.toggleKeyboard() }, for: .touchUpInside)
        CarUI.setSymbol(keyboardButton, "keyboard", size: 18)
        phoneButton.addAction(UIAction { [weak self] _ in
            self?.bridge.isPhoneEditorPresented = true
            self?.hintLabel.text = "اكتب الآن من لوحة مفاتيح CarPlay على الهاتف."
        }, for: .touchUpInside)

        let bottom = UIStackView(arrangedSubviews: [phoneButton, keyboardButton, languageButton])
        bottom.axis = .horizontal
        bottom.spacing = 12
        bottom.distribution = .fill
        phoneButton.widthAnchor.constraint(equalToConstant: 70).isActive = true
        keyboardButton.widthAnchor.constraint(equalTo: languageButton.widthAnchor).isActive = true

        [top, middle, bottom].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        let guide = safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: guide.topAnchor, constant: 10),
            top.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 14),
            top.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -14),
            top.heightAnchor.constraint(equalToConstant: 58),

            middle.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 8),
            middle.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 10),
            middle.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -10),
            middle.bottomAnchor.constraint(equalTo: bottom.topAnchor, constant: -8),

            bottom.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 14),
            bottom.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -14),
            bottom.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -10),
            bottom.heightAnchor.constraint(equalToConstant: 52)
        ])
        updateLanguageButton()
    }

    private func bind() {
        bridge.textChanges
            .filter { $0.1 == .phone }
            .receive(on: RunLoop.main)
            .sink { [weak self] value in self?.apply(value.0, toBridge: false) }
            .store(in: &bag)
        bridge.submits
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                SpeechDictation.shared.stop()
                self.onSubmit?(self.text)
            }
            .store(in: &bag)
        bridge.cancels
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                SpeechDictation.shared.stop()
                self?.onCancel?()
            }
            .store(in: &bag)
    }

    // MARK: الحالة

    private func apply(_ newText: String, toBridge: Bool) {
        text = newText
        render()
        onLiveText?(newText)
        if toBridge { bridge.setText(newText, from: .car) }
    }

    private func render() {
        if text.isEmpty {
            textLabel.text = placeholder
            textLabel.textColor = .gray
        } else {
            textLabel.text = text
            textLabel.textColor = .white
        }
        textLabel.textAlignment = (text.isEmpty ? placeholder : text).containsArabic ? .right : .left
        clearButton.isHidden = text.isEmpty
    }

    private func toggleLanguage() {
        isArabic.toggle()
        WDSettings.carInputIsArabic = isArabic
        updateLanguageButton()
        keyboard.setLayout(isArabic ? .arabic : .english)
    }

    private func updateLanguageButton() {
        CarUI.setTitle(languageButton, isArabic ? "العربية" : "English", size: 18)
    }

    private func toggleKeyboard() {
        keyboardShown.toggle()
        micButton.isHidden = keyboardShown
        hintLabel.isHidden = keyboardShown
        if keyboardShown {
            keyboard.translatesAutoresizingMaskIntoConstraints = false
            middle.addSubview(keyboard)
            CarUI.pin(keyboard, to: middle)
        } else {
            keyboard.removeFromSuperview()
        }
    }

    private func toggleListening() {
        if listening {
            SpeechDictation.shared.stop()
            return
        }
        listening = true
        setMicActive(true)
        hintLabel.text = "تكلّم الآن…"
        SpeechDictation.shared.start(
            localeID: isArabic ? "ar-SA" : "en-US",
            onText: { [weak self] spoken in self?.apply(spoken, toBridge: true) },
            onEnd: { [weak self] in
                self?.listening = false
                self?.setMicActive(false)
                self?.hintLabel.text = "اضغط بحث للمتابعة، أو الميكروفون للمحاولة مرة أخرى."
            }
        )
    }

    private func setMicActive(_ active: Bool) {
        var config = micButton.configuration
        config?.baseBackgroundColor = active ? .systemRed : CarUI.accent
        config?.image = UIImage(systemName: active ? "stop.fill" : "mic.fill",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 40, weight: .medium))
        micButton.configuration = config
    }
}
