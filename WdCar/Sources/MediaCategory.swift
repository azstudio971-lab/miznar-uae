import Foundation

enum MediaCategory: String, CaseIterable, Identifiable {
    case all, news, sports, movies, series, kids, documentary, music, religious, education, entertainment, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return tr("الكل", "All")
        case .news: return tr("أخبار", "News")
        case .sports: return tr("رياضة", "Sports")
        case .movies: return tr("أفلام", "Movies")
        case .series: return tr("مسلسلات", "Series")
        case .kids: return tr("أطفال", "Kids")
        case .documentary: return tr("وثائقي", "Documentary")
        case .music: return tr("موسيقى", "Music")
        case .religious: return tr("ديني", "Religious")
        case .education: return tr("تعليم", "Education")
        case .entertainment: return tr("ترفيه", "Entertainment")
        case .other: return tr("أخرى", "Other")
        }
    }
    static func classify(_ group: String) -> MediaCategory {
        let values: [(MediaCategory, [String])] = [(.news,["news","أخبار","اخبار"]),(.sports,["sport","رياض","bein"]),(.movies,["movie","film","cinema","أفلام","افلام"]),(.series,["series","season","مسلس","episode"]),(.kids,["kid","child","أطفال","اطفال","cartoon"]),(.documentary,["document","وثائق"]),(.music,["music","موسيقى","غناء"]),(.religious,["quran","islam","relig","قرآن","قران","ديني"]),(.education,["educat","تعليم"]),(.entertainment,["entertain","ترفيه"])]
        return values.first { $0.1.contains { group.localizedCaseInsensitiveContains($0) } }?.0 ?? .other
    }
}
