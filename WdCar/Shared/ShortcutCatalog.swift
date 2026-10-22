import Foundation

/// Versioned seed data. User-edited entries are never deleted by this upgrade.
enum ShortcutCatalog {
    static let entries: [(String, String, String)] = [
        ("YouTube", "https://www.youtube.com", "#ED1018"),
        ("YouTube Music", "https://music.youtube.com", "#780B16"),
        ("YouTube Kids", "https://www.youtubekids.com", "#F2F5FA"),
        ("Google Search", "https://www.google.com", "#EDF3FA"),
        ("Alawi TV", "https://tv2tv.com/login", "#18191B"),
        ("MP3Quran", "https://www.mp3quran.net/", "#006B4E"),
        ("Shahid", "https://shahid.mbc.net", "#00394D"),
        ("TikTok", "https://www.tiktok.com", "#101115"),
        ("Instagram", "https://www.instagram.com", "#C92388"),
        ("TOD", "https://www.tod.tv/ar", "#171718"),
        ("SoundCloud", "https://m.soundcloud.com/", "#F56A05"),
        ("UAE Weather", "https://www.rain.ae/", "#0757B9"),
        ("Spotify", "https://open.spotify.com", "#003C28"),
        ("Apple TV", "https://tv.apple.com/ae", "#111215"),
        ("Radio Garden", "https://radio.garden", "#033B40"),
        ("Dailymotion", "https://www.dailymotion.com", "#0754D9"),
        ("Vimeo", "https://vimeo.com", "#086D91"),
        ("Twitch", "https://www.twitch.tv", "#6330BE"),
        ("STARZPLAY", "https://www.starzplay.com", "#141824"),
        ("Dubai+", "https://www.dubaiplus.net", "#2B174F"),
        ("Awaan", "https://www.awaan.ae", "#6B145C"),
        ("Filmzie", "https://filmzie.com", "#242E42"),
        ("Spacetoon GO", "https://spacetoongo.com/ar", "#125A87"),
        ("PBS Kids", "https://pbskids.org", "#3E6724"),
        ("CrazyGames", "https://www.crazygames.com/", "#39205E"),
        ("Windows XP Simulator", "https://pranx.com/windows-xp-simulator/", "#145EB0"),
        ("Outlook", "https://outlook.live.com/mail/", "#075EA9"),
        ("Gmail", "https://mail.google.com/", "#F2F4F7"),
        ("ChatGPT", "https://chatgpt.com/", "#075247")
    ]

    static var defaults: [SiteShortcut] {
        entries.enumerated().map { index, entry in
            SiteShortcut(id: UUID(uuidString: String(format: "17000000-0000-0000-0000-%012d", index + 1))!,
                         name: entry.0, url: URL(string: entry.1)!, colorHex: entry.2)
        }
    }

    static func identity(_ url: URL) -> String {
        var host = (url.host ?? "").lowercased()
        for prefix in ["www.", "m."] where host.hasPrefix(prefix) { host.removeFirst(prefix.count) }
        return host + (url.path == "/" ? "" : url.path.lowercased())
    }

    private static func siteHost(_ url: URL) -> String {
        var host = (url.host ?? "").lowercased()
        for prefix in ["www.", "m."] where host.hasPrefix(prefix) { host.removeFirst(prefix.count) }
        return host
    }

    static func isLegacySeed(_ item: SiteShortcut) -> Bool {
        item.iconURL == nil && legacy.contains {
            item.name == $0.0 && item.colorHex == $0.2 && identity(item.url) == identity(URL(string: $0.1)!)
        }
    }

    static func upgrade(_ saved: [SiteShortcut]) -> [SiteShortcut] {
        let custom = saved.filter { !isLegacySeed($0) }
        var result: [SiteShortcut] = []
        for seed in defaults {
            let key = siteHost(seed.url)
            if let userItem = custom.first(where: { siteHost($0.url) == key }) {
                result.append(userItem)
            } else if let old = saved.first(where: { siteHost($0.url) == key }) {
                var updated = seed
                updated.id = old.id
                updated.url = old.url
                result.append(updated)
            } else { result.append(seed) }
        }
        // Preserve custom/edited records and their IDs, URLs, icons and colors exactly.
        let used = Set(result.map(\.id))
        result.append(contentsOf: custom.filter { !used.contains($0.id) })
        return result
    }
    static let legacy: [(String, String, String)] = [
            ("طقس الإمارات", "https://www.rain.ae/", "#187DA6"),
            ("YouTube", "https://www.youtube.com", "#FF0000"),
            ("TikTok", "https://www.tiktok.com", "#111111"),
            ("Google", "https://www.google.com", "#FFFFFF"),
            ("شاهد", "https://shahid.mbc.net", "#1E1E1E"),
            ("Instagram", "https://www.instagram.com", "#E1306C"),
            ("Twitch", "https://www.twitch.tv", "#9146FF"),
            ("Vimeo", "https://vimeo.com", "#1AB7EA"),
            ("Dailymotion", "https://www.dailymotion.com", "#0066DC"),
            ("Pluto TV", "https://pluto.tv", "#2D2D8F"),
            ("Tubi", "https://tubitv.com", "#7408FF"),
            ("Plex", "https://app.plex.tv", "#E5A00D"),
            ("Crunchyroll", "https://www.crunchyroll.com", "#F47521"),
            ("القرآن الكريم – MP3Quran", "https://www.mp3quran.net/", "#168A65"),
            ("SoundCloud – ساوند كلاود", "https://m.soundcloud.com/", "#FF5500"),
            ("Netflix – نتفليكس", "https://www.netflix.com/", "#E50914"),
            ("Windows XP – محاكي ويندوز XP", "https://pranx.com/windows-xp-simulator/", "#1683D8"),
            ("علوي TV – Alawi TV", "https://tv2tv.com/login", "#134A72"),
            ("Prime Video – برايم فيديو", "https://www.primevideo.com/", "#00A8E1"),
            ("TOD – منصة تود", "https://www.tod.tv/ar", "#F4A900"),
            ("CrazyGames – كريزي جيمز", "https://www.crazygames.com/", "#1C1C1C"),
            ("Gmail", "https://mail.google.com/", "#EA4335"),
            ("Outlook", "https://outlook.live.com/mail/", "#0078D4"),
            ("ChatGPT", "https://chatgpt.com/", "#10A37F")
    ]

}
