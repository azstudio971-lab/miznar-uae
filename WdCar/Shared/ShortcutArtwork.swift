import UIKit

enum ShortcutArtwork {
    private static let assets: [String: String] = [
        "youtube.com": "Site17youtube",
        "music.youtube.com": "Site17youtubemusic",
        "youtubekids.com": "Site17youtubekids",
        "google.com": "Site17googlesearch",
        "tv2tv.com": "Site17alawitv",
        "mp3quran.net": "Site17mp3quran",
        "shahid.mbc.net": "Site17shahid",
        "tiktok.com": "Site17tiktok",
        "instagram.com": "Site17instagram",
        "soundcloud.com": "Site17soundcloud",
        "open.spotify.com": "Site17spotify",
        "tv.apple.com": "Site17appletv",
        "radio.garden": "Site17radiogarden",
        "dailymotion.com": "Site17dailymotion",
        "vimeo.com": "Site17vimeo",
        "twitch.tv": "Site17twitch",
        "dubaiplus.net": "Site17dubai",
        "awaan.ae": "Site17awaan",
        "filmzie.com": "Site17filmzie",
        "spacetoongo.com": "Site17spacetoongo",
        "pbskids.org": "Site17pbskids",
        "crazygames.com": "Site17crazygames",
        "pranx.com": "Site17windowsxpsimulator",
        "mail.google.com": "Site17gmail",
        "chatgpt.com": "Site17chatgpt",
    ]
    static func bundled(for item: SiteShortcut) -> UIImage? {
        guard item.iconURL == nil else { return nil }
        var host = (item.url.host ?? "").lowercased()
        for prefix in ["www.", "m."] where host.hasPrefix(prefix) { host.removeFirst(prefix.count) }
        return assets[host].flatMap { UIImage(named: $0) }
    }
}
