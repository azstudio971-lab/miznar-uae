import UIKit
import SwiftUI
import Combine

/// Optional artwork never replaces the bundled base. No stale disk image is used offline.
final class SeasonalLogo: ObservableObject {
    static let shared = SeasonalLogo()
    static let url = URL(string: "https://wudcar.netlify.app/branding/occasion.png")!
    @Published private(set) var image: UIImage?
    private var loading = false
    private var lastRequest = Date.distantPast
    private var timer: Timer?
    private init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in self?.refresh() }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.refresh() }
    }
    func refresh() {
        guard !loading, Date().timeIntervalSince(lastRequest) >= 30 else { return }
        loading = true
        lastRequest = Date()
        var request = URLRequest(url: Self.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            var validated: UIImage?
            if let response = response as? HTTPURLResponse, response.statusCode == 200,
               response.mimeType == "image/png", let data, data.count <= 4_000_000,
               let image = UIImage(data: data), image.size.width > 0, image.size.height > 0,
               image.size.width == 512, image.size.height == 512 {
                validated = image
            }
            DispatchQueue.main.async { self?.image = validated; self?.loading = false }
        }.resume()
    }
}

final class SeasonalLogoView: UIView {
    private var subscription: AnyCancellable?
    init(base: UIImage?) {
        super.init(frame: .zero)
        let original = UIImageView(image: base)
        let overlay = UIImageView()
        for image in [original, overlay] {
            image.contentMode = .scaleAspectFit
            addSubview(image)
            CarUI.pin(image, to: self)
        }
        subscription = SeasonalLogo.shared.$image.sink { overlay.image = $0 }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

struct SeasonalLogoOverlay: View {
    @ObservedObject private var artwork = SeasonalLogo.shared
    var body: some View {
        GeometryReader { geometry in
            if let image = artwork.image {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
