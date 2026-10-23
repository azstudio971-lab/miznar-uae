import SwiftUI
import AVFoundation
import PhotosUI
import Vision

struct QRScannerView: UIViewControllerRepresentable {
    let completion: (String) -> Void
    func makeUIViewController(context: Context) -> QRScannerController { QRScannerController(completion: completion) }
    func updateUIViewController(_ controller: QRScannerController, context: Context) {}
}
final class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "wd.qr.capture")
    private let completion: (String) -> Void
    private var preview: AVCaptureVideoPreviewLayer?
    private var completed = false
    init(completion: @escaping (String) -> Void) { self.completion = completion; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .black
        let close = UIButton(type: .system); close.setTitle(tr("إغلاق", "Close"), for: .normal)
        close.addTarget(self, action: #selector(closeScanner), for: .touchUpInside)
        close.frame = CGRect(x: 20, y: 50, width: 90, height: 44); view.addSubview(close)
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted { self.configure() } else { self.showFailure(tr("الوصول إلى الكاميرا معطّل. فعّله من إعدادات iPhone لمسح QR.", "Camera access is disabled. Enable it in iPhone Settings to scan QR.")) }
            }
        }
    }
    private func configure() {
        guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { showFailure(tr("الكاميرا غير متاحة.", "Camera is unavailable.")); return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }; session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main); output.metadataObjectTypes = [.qr]
        let preview = AVCaptureVideoPreviewLayer(session: session); preview.videoGravity = .resizeAspectFill; preview.frame = view.bounds
        self.preview = preview; view.layer.insertSublayer(preview, at: 0)
        queue.async { [session] in session.startRunning() }
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); preview?.frame = view.bounds }
    override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); queue.async { [session] in session.stopRunning() } }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !completed, let value = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        completed = true; completion(value)
    }
    private func showFailure(_ text: String) {
        let label = UILabel(frame: view.bounds.insetBy(dx: 30, dy: 120)); label.text = text; label.textColor = .white; label.numberOfLines = 0; label.textAlignment = .center; view.addSubview(label)
    }
    @objc private func closeScanner() { dismiss(animated: true) }
}
struct QRPhotoPicker: UIViewControllerRepresentable {
    let completion: (String?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(); config.filter = .images; config.selectionLimit = 1
        let controller = PHPickerViewController(configuration: config); controller.delegate = context.coordinator; return controller
    }
    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let completion: (String?) -> Void
        init(completion: @escaping (String?) -> Void) { self.completion = completion }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { completion(nil); return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                var value: String?
                if let data = (image as? UIImage)?.pngData() {
                    value = QRImageDecoder.payload(data: data)
                }
                DispatchQueue.main.async { self.completion(value) }
            }
        }
    }
}

/// Vision's simulator model compiler needs CPU inference in a virtual machine.
enum QRImageDecoder {
    static func payload(data: Data) -> String? {
        let request = request()
        if (try? VNImageRequestHandler(data: data).perform([request])) != nil,
           let value = request.results?.first?.payloadStringValue { return value }
        guard let image = CIImage(data: data),
              let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: CIContext(options: [.useSoftwareRenderer: true]), options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]) else { return nil }
        return (detector.features(in: image).first as? CIQRCodeFeature)?.messageString
    }
    static func request() -> VNDetectBarcodesRequest {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        request.revision = VNDetectBarcodesRequestRevision1
        #if targetEnvironment(simulator)
        request.usesCPUOnly = true
        #endif
        return request
    }
}
