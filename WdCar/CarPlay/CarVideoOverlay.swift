import UIKit

/// مشغل ود كار فوق الفيديو بملء الشاشة:
/// خروج + مقاس الشاشة (أعلى) — رجوع 10 ث / تشغيل / تقديم 10 ث (الوسط) — شريط تقدّم قابل للسحب + الوقت (أسفل)
/// (تحسين على CarTV: الشريط هنا يتحكم بالتقديم والتأخير)
final class CarVideoOverlayView: UIView, UIGestureRecognizerDelegate {
    var onExit: (() -> Void)?
    var onFitChange: ((VideoFit) -> Void)?
    var onTogglePlay: (() -> Void)?
    var onSeekBy: ((Double) -> Void)?
    var onSeekTo: ((Double) -> Void)?

    private var fit: VideoFit = .contain
    private let controls = UIView()
    private let exitButton = CarUI.iconButton("arrow.down.right.and.arrow.up.left", size: 18, background: UIColor(white: 0, alpha: 0.55))
    private let fitButton = CarUI.textButton("ملاءمة", size: 15, background: UIColor(white: 0, alpha: 0.55))
    private let backButton = CarUI.iconButton("gobackward.10", size: 26, background: UIColor(white: 0, alpha: 0.45))
    private let playButton = CarUI.iconButton("pause.fill", size: 32, background: UIColor(white: 0, alpha: 0.45))
    private let forwardButton = CarUI.iconButton("goforward.10", size: 26, background: UIColor(white: 0, alpha: 0.45))
    private let slider = UISlider()
    private let timeLabel = UILabel()
    private var isScrubbing = false
    private var hideWork: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        semanticContentAttribute = .forceLeftToRight
        build()
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleControls))
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        addSubview(controls)
        CarUI.pin(controls, to: self)

        exitButton.addAction(UIAction { [weak self] _ in self?.onExit?() }, for: .touchUpInside)
        fitButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.fit = self.fit.next
            CarUI.setTitle(self.fitButton, self.fit.title, size: 15)
            self.onFitChange?(self.fit)
            self.scheduleHide()
        }, for: .touchUpInside)
        backButton.addAction(UIAction { [weak self] _ in self?.onSeekBy?(-10); self?.scheduleHide() }, for: .touchUpInside)
        forwardButton.addAction(UIAction { [weak self] _ in self?.onSeekBy?(10); self?.scheduleHide() }, for: .touchUpInside)
        playButton.addAction(UIAction { [weak self] _ in self?.onTogglePlay?(); self?.scheduleHide() }, for: .touchUpInside)

        let topStack = UIStackView(arrangedSubviews: [exitButton, fitButton])
        topStack.spacing = 10

        let centerStack = UIStackView(arrangedSubviews: [backButton, playButton, forwardButton])
        centerStack.spacing = 40
        centerStack.alignment = .center
        [backButton, forwardButton].forEach {
            $0.widthAnchor.constraint(equalToConstant: 66).isActive = true
            $0.heightAnchor.constraint(equalToConstant: 66).isActive = true
        }
        playButton.widthAnchor.constraint(equalToConstant: 84).isActive = true
        playButton.heightAnchor.constraint(equalToConstant: 84).isActive = true

        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = UIColor(white: 1, alpha: 0.3)
        slider.setThumbImage(Self.thumbImage(), for: .normal)
        slider.semanticContentAttribute = .forceLeftToRight
        slider.addAction(UIAction { [weak self] _ in
            self?.isScrubbing = true
            self?.hideWork?.cancel()
        }, for: .touchDown)
        slider.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.isScrubbing = false
            self.onSeekTo?(Double(self.slider.value))
            self.scheduleHide()
        }, for: [.touchUpInside, .touchUpOutside, .touchCancel])

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
        timeLabel.textColor = .white
        timeLabel.text = "0:00 / 0:00"
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)

        let bar = UIStackView(arrangedSubviews: [slider, timeLabel])
        bar.spacing = 14
        bar.alignment = .center
        bar.isLayoutMarginsRelativeArrangement = true
        bar.layoutMargins = UIEdgeInsets(top: 8, left: 18, bottom: 8, right: 18)
        bar.backgroundColor = UIColor(white: 0, alpha: 0.55)
        bar.layer.cornerRadius = 24

        [topStack, centerStack, bar].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            controls.addSubview($0)
        }
        let guide = safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            topStack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            topStack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 14),

            centerStack.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: guide.centerYAnchor),

            bar.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            bar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            bar.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -14),
            bar.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    // MARK: الواجهة العامة

    func present() {
        isHidden = false
        fit = .contain
        CarUI.setTitle(fitButton, fit.title, size: 15)
        showControls()
    }

    func update(_ status: VideoStatus) {
        guard !isScrubbing else { return }
        slider.value = status.duration > 0 ? Float(status.current / status.duration) : 0
        timeLabel.text = "\(CarUI.formatTime(status.current)) / \(CarUI.formatTime(status.duration))"
        CarUI.setSymbol(playButton, status.playing ? "pause.fill" : "play.fill", size: 32)
    }

    // MARK: الإظهار والإخفاء التلقائي

    @objc private func toggleControls() {
        if controls.alpha > 0.5 { hideControls() } else { showControls() }
    }

    private func showControls() {
        UIView.animate(withDuration: 0.2) { self.controls.alpha = 1 }
        scheduleHide()
    }

    private func hideControls() {
        hideWork?.cancel()
        UIView.animate(withDuration: 0.3) { self.controls.alpha = 0 }
    }

    private func scheduleHide() {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hideControls() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !(touch.view?.isInsideControl ?? false)
    }

    private static func thumbImage() -> UIImage {
        let size = CGSize(width: 18, height: 18)
        return UIGraphicsImageRenderer(size: size).image { _ in
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
        }
    }
}

/// غطاء يظهر عند حركة السيارة ويوقف الفيديو
final class CarDrivingLockView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.03, alpha: 0.96)

        let icon = UIImageView(image: UIImage(systemName: "car.fill",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 54, weight: .medium)))
        icon.tintColor = CarUI.accent

        let title = UILabel()
        title.text = "الفيديو متوقف أثناء القيادة"
        title.font = .systemFont(ofSize: 26, weight: .bold)
        title.textColor = .white

        let subtitle = UILabel()
        subtitle.text = "سيعود التشغيل متاحاً عند توقف السيارة."
        subtitle.font = .systemFont(ofSize: 18, weight: .medium)
        subtitle.textColor = .lightGray

        let stack = UIStackView(arrangedSubviews: [icon, title, subtitle])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
