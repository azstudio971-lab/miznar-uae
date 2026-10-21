import UIKit

/// أي متصفح: الهاتف أو السيارة. لكل واحد علامات تبويب مستقلة (مثل CarTV)
enum BrowserSide: String, Codable, Hashable {
    case phone, car
}

struct BrowserTab: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var url: URL?
    var title: String = ""

    var displayTitle: String {
        if !title.isEmpty { return title }
        return url?.host ?? "صفحة جديدة"
    }
}

struct SiteShortcut: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var url: URL
    var colorHex: String
    var iconURL: URL? = nil
}

struct FocusInfo {
    let value: String
    let placeholder: String
}

struct VideoStatus: Equatable {
    var current: Double = 0
    var duration: Double = 0
    var playing: Bool = false
}

/// طريقة ملء الفيديو للشاشة
enum VideoFit: String, CaseIterable {
    case contain, cover, fill

    var next: VideoFit {
        let all = VideoFit.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    var title: String {
        switch self {
        case .contain: return "ملاءمة"
        case .cover: return "تعبئة"
        case .fill: return "تمدد لملء الشاشة"
        }
    }
}

// MARK: - تحويل النص المكتوب إلى رابط أو بحث جوجل

enum URLInput {
    static func resolve(_ raw: String, allowSearch: Bool = true) -> URL? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let url = URL(string: text),
           let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme),
           url.host != nil {
            return url
        }
        if !text.contains(" "), text.contains("."),
           let url = URL(string: "https://" + text), url.host != nil {
            return url
        }
        guard allowSearch else { return nil }
        var components = URLComponents(string: "https://www.google.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: text)]
        return components.url
    }
}

enum Favicon {
    static func url(for site: URL) -> URL? {
        guard let host = site.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?sz=128&domain=\(host)")
    }
}

// MARK: - تحميل الصور مع ذاكرة مؤقتة

final class ImageLoader {
    static let shared = ImageLoader()
    private let cache = NSCache<NSURL, UIImage>()

    func load(_ url: URL?, completion: @escaping (UIImage?) -> Void) {
        guard let url else { completion(nil); return }
        if let cached = cache.object(forKey: url as NSURL) { completion(cached); return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            let image = data.flatMap(UIImage.init(data:))
            if let image { self?.cache.setObject(image, forKey: url as NSURL) }
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }
}

extension UIColor {
    convenience init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") { value.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: value).scanHexInt64(&rgb)
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: 1)
    }
}

extension String {
    var containsArabic: Bool {
        unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) || (0xFE70...0xFEFF).contains($0.value) }
    }
}
