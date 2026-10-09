import Foundation

struct Preferences: Codable, Equatable {
    var name = ""
    var language = Locale.preferredLanguages.first?.hasPrefix("ar") == true ? "ar" : "en"
    var city = "Dubai"
    var region = "Dubai"
    var country = "AE"
    var timezone = "Asia/Dubai"
    var locationMode = "manual"
    var latitude: Double?
    var longitude: Double?
    var favoriteIDs: [String] = []
    var themeID = "spirit-of-the-uae"
    var musicEnabled = false
    var widgets = ["clock": true, "date": true, "greeting": true, "weather": true, "prayer": true, "adhkar": true, "music": false]
    var widgetScale = 1.0
    var widgetOpacity = 1.0
    var clockX = 0.72
    var clockY = 0.20
    var onboarded = false
    var clockStyle = "digital"
    var uses24HourClock = false
    var showHijri = true
    var appearance = "system"
    var prayerMethod = 8
    var widgetOverrides: [String:WidgetCustomization] = [:]
}
struct ThemeSlot: Codable, Equatable { let period: String; let start: Int; let end: Int }
struct ThemeAsset: Codable, Identifiable {
    var id: String { "\(layout)-\(period)" }
    let layout: String; let period: String; let kind: String; let url: String
}
struct Theme: Codable, Identifiable {
    let id: String; var name_ar: String; var name_en: String; var version: Int
    var timezone: String; var slots: [ThemeSlot]; var widgets: [String: Bool]
    var music_mode: String; var music_ids: [String]; var assets: [ThemeAsset]
    var forced: Bool?; var starts_at: String?; var ends_at: String?
    var priority: Int?; var sort_order: Int?; var weekdays: [Int]?
    var description_ar: String?; var description_en: String?
    var thumbnail_url: String?; var fallback_url: String?
    var media: [ThemeMedium]?; var widget_settings: [WidgetLayout]?
    func name(_ language: String) -> String { language == "ar" ? name_ar : name_en }
    static let builtin = Theme(id: "spirit-of-the-uae", name_ar: "روح الإمارات", name_en: "Spirit of the UAE", version: 1, timezone: "Asia/Dubai", slots: [ThemeSlot(period:"dawn",start:300,end:420), ThemeSlot(period:"morning",start:420,end:1020), ThemeSlot(period:"sunset",start:1020,end:1140), ThemeSlot(period:"night",start:1140,end:300)], widgets: ["clock":true,"date":true,"greeting":true,"weather":true,"prayer":true,"adhkar":true,"allow_move":true,"allow_resize":true], music_mode:"all",music_ids:[],assets:[])
}
struct Track: Codable, Identifiable {let id: String;let name_ar: String;let name_en: String;let url: String}
struct Catalog: Codable {let themes:[Theme];let music:[Track];let default_theme:String?;let religious:[ReligiousContent]?;let settings:CatalogSettings?;let legal:[RemotePolicy]?;let library:[LibraryItem]?;let updates:[AppUpdate]?}
struct InboxMessage: Codable, Identifiable {let id:String;let title_ar:String;let title_en:String;let body_ar:String;let body_en:String}
struct MediaSource: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var name: String
    var url: String
    var type: String // playlist, stream, local, website
    var mediaKind: String // audio or video
    var favorite = false
}
struct MediaItem: Identifiable, Hashable {var id: String {url.absoluteString};let name:String;let url:URL;let group:String}
struct City: Identifiable {var id:String{name};let name:String;let arabic:String;let lat:Double;let lon:Double
    static let all = [City(name:"Dubai",arabic:"دبي",lat:25.2048,lon:55.2708),City(name:"Abu Dhabi",arabic:"أبوظبي",lat:24.4539,lon:54.3773),City(name:"Sharjah",arabic:"الشارقة",lat:25.3463,lon:55.4209),City(name:"Fujairah",arabic:"الفجيرة",lat:25.1288,lon:56.3265),City(name:"Dibba",arabic:"دبا",lat:25.592,lon:56.261),City(name:"Ras Al Khaimah",arabic:"رأس الخيمة",lat:25.7895,lon:55.9432),City(name:"Ajman",arabic:"عجمان",lat:25.4052,lon:55.5136),City(name:"Umm Al Quwain",arabic:"أم القيوين",lat:25.5647,lon:55.5552)]
}
enum WudDomain {
    static func greeting(name:String,hour:Int,language:String)->String {
        let value=String(name.trimmingCharacters(in:.whitespacesAndNewlines).prefix(40))
        let greeting=language == "ar" ? (hour < 12 ? "صباح الخير" : "مساء الخير") : (hour < 12 ? "Good morning" : "Good evening")
        return greeting + (value.isEmpty ? "" : (language == "ar" ? " يا " : ", ") + value)
    }
    static func layout(width:Double,height:Double)->String {height > 0 && width/height >= 1.9 ? "ultrawide" : "compact"}
    static func validURL(_ text:String)->URL? {guard let u=URL(string:text.trimmingCharacters(in:.whitespacesAndNewlines)),u.scheme?.lowercased()=="https",u.host != nil,u.user==nil,u.password==nil else{return nil};return u}
    static func validSlots(_ slots:[ThemeSlot])->Bool {
        guard slots.count==4,Set(slots.map(\.period))==Set(["dawn","morning","sunset","night"]) else{return false}
        var minutes=Array(repeating:0,count:1440)
        for slot in slots {guard (0..<1440).contains(slot.start),(0..<1440).contains(slot.end),slot.start != slot.end else{return false};var m=slot.start;while m != slot.end {minutes[m]+=1;if minutes[m]>1{return false};m=(m+1)%1440}}
        return minutes.allSatisfy{$0==1}
    }
    static func period(date:Date,theme:Theme)->String {
        var c=Calendar(identifier:.gregorian);c.timeZone=TimeZone(identifier:theme.timezone) ?? .current
        let minute=c.component(.hour,from:date)*60+c.component(.minute,from:date)
        guard validSlots(theme.slots) else{return "morning"}
        return theme.slots.first{s in s.start<s.end ? minute>=s.start && minute<s.end : minute>=s.start || minute<s.end}?.period ?? "morning"
    }
    static func parseM3U(_ text:String,base:URL)->[MediaItem] {
        var result:[MediaItem]=[],name="Media",group=""
        for raw in text.components(separatedBy:.newlines) {let line=raw.trimmingCharacters(in:.whitespacesAndNewlines)
            if line.hasPrefix("#EXTINF:") {name=line.split(separator:",",maxSplits:1).last.map(String.init) ?? "Media";group="";if let range=line.range(of:"group-title=\""){let rest=line[range.upperBound...];group=String(rest.prefix{ $0 != "\"" })}}
            else if !line.isEmpty && !line.hasPrefix("#"),let u=URL(string:line,relativeTo:base)?.absoluteURL,validURL(u.absoluteString) != nil {result.append(MediaItem(name:name,url:u,group:group));name="Media";group=""}
        };return result
    }
}

struct WidgetCustomization: Codable, Equatable { var x:Double;var y:Double;var scale:Double;var opacity:Double;var hidden:Bool }
struct WidgetLayout: Codable, Identifiable {var id:String{widget_id};let widget_id:String;var visible:Bool;var x:Double;var y:Double;var scale:Double;var opacity:Double;var sort_order:Int;var allow_move:Bool;var allow_resize:Bool;var allow_hide:Bool}
struct ThemeMedium: Codable, Identifiable {let id:String;let layout:String;let period:String;let kind:String;let url:String;let sort_order:Int;let duration_seconds:Int}
struct ReligiousContent: Codable, Identifiable {let id:String;let kind:String;let title_ar:String;let title_en:String;let text_ar:String;let text_en:String;let source_title:String;let source_url:String}
struct CatalogSettings:Codable {var maintenance:Bool?;var minimum_version:String?;var refresh_seconds:Int?;var splash_enabled:Bool?;var splash_duration:Double?;var subscriptions_enabled:Bool?;var trial_enabled:Bool?}
struct RemotePolicy:Codable,Identifiable {let id:String;let title_ar:String;let title_en:String;let sections_ar:[[String]];let sections_en:[[String]];let version:Int}
struct RegisteredDevice:Codable,Identifiable {let id:String;let name:String;let last_seen_at:String;let revoked_at:String?}

extension Preferences {
    private enum CodingKeys:String,CodingKey {case region,country,timezone,locationMode,latitude,longitude,favoriteIDs,name,language,city,themeID,musicEnabled,widgets,widgetScale,widgetOpacity,clockX,clockY,onboarded,clockStyle,uses24HourClock,showHijri,appearance,prayerMethod,widgetOverrides}
    init(from decoder:Decoder)throws {
        self.init();let c=try decoder.container(keyedBy:CodingKeys.self)
        name=try c.decodeIfPresent(String.self,forKey:.name) ?? name
        language=try c.decodeIfPresent(String.self,forKey:.language) ?? language
        city=try c.decodeIfPresent(String.self,forKey:.city) ?? city
        region=try c.decodeIfPresent(String.self,forKey:.region) ?? region
        country=try c.decodeIfPresent(String.self,forKey:.country) ?? country
        timezone=try c.decodeIfPresent(String.self,forKey:.timezone) ?? timezone
        locationMode=try c.decodeIfPresent(String.self,forKey:.locationMode) ?? locationMode
        latitude=try c.decodeIfPresent(Double.self,forKey:.latitude)
        longitude=try c.decodeIfPresent(Double.self,forKey:.longitude)
        favoriteIDs=try c.decodeIfPresent([String].self,forKey:.favoriteIDs) ?? []
        themeID=try c.decodeIfPresent(String.self,forKey:.themeID) ?? themeID
        musicEnabled=try c.decodeIfPresent(Bool.self,forKey:.musicEnabled) ?? musicEnabled
        widgets=try c.decodeIfPresent([String:Bool].self,forKey:.widgets) ?? widgets
        widgetScale=try c.decodeIfPresent(Double.self,forKey:.widgetScale) ?? widgetScale
        widgetOpacity=try c.decodeIfPresent(Double.self,forKey:.widgetOpacity) ?? widgetOpacity
        clockX=try c.decodeIfPresent(Double.self,forKey:.clockX) ?? clockX
        clockY=try c.decodeIfPresent(Double.self,forKey:.clockY) ?? clockY
        onboarded=try c.decodeIfPresent(Bool.self,forKey:.onboarded) ?? onboarded
        clockStyle=try c.decodeIfPresent(String.self,forKey:.clockStyle) ?? clockStyle
        uses24HourClock=try c.decodeIfPresent(Bool.self,forKey:.uses24HourClock) ?? uses24HourClock
        showHijri=try c.decodeIfPresent(Bool.self,forKey:.showHijri) ?? showHijri
        appearance=try c.decodeIfPresent(String.self,forKey:.appearance) ?? appearance
        prayerMethod=try c.decodeIfPresent(Int.self,forKey:.prayerMethod) ?? prayerMethod
        widgetOverrides=try c.decodeIfPresent([String:WidgetCustomization].self,forKey:.widgetOverrides) ?? widgetOverrides
    }
}

struct LibraryItem: Codable, Identifiable {let id:String;let kind:String;let name_ar:String;let name_en:String;let url:String;let icon_url:String?;let description_ar:String?;let description_en:String?
    func name(_ lang:String)->String {lang == "ar" ? name_ar : name_en}
}
struct AppUpdate: Codable, Identifiable {let id:String;let title_ar:String;let title_en:String;let body_ar:String;let body_en:String;let version:String}
