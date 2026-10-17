import Speech
import AVFoundation

/// البحث الصوتي في شاشة السيارة (زر الميكروفون الأخضر)
final class SpeechDictation {
    static let shared = SpeechDictation()

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var onEnd: (() -> Void)?
    private(set) var isRunning = false

    func start(localeID: String, onText: @escaping (String) -> Void, onEnd: @escaping () -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else { onEnd(); return }
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        guard granted else { onEnd(); return }
                        self.begin(localeID: localeID, onText: onText, onEnd: onEnd)
                    }
                }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        // نرجع جلسة الصوت لوضع تشغيل الفيديو
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
        let finished = onEnd
        onEnd = nil
        finished?()
    }

    private func begin(localeID: String, onText: @escaping (String) -> Void, onEnd: @escaping () -> Void) {
        stop()
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID)), recognizer.isAvailable else {
            onEnd()
            return
        }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request
        self.onEnd = onEnd

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            self.onEnd = nil
            onEnd()
            return
        }
        isRunning = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async { onText(text) }
            }
            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async { self?.stop() }
            }
        }
    }
}
