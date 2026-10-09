import Foundation

struct Preferences: Codable, Equatable {
    var name = ""
    var language = "ar"
    var city = "Dubai"
    var themeID = "spirit-of-the-uae"
    var musicEnabled = false
    var widgets = ["clock": true, "date": true, "greeting": true, "weather": true, "prayer": true, "adhkar": true]
    var widgetScale = 1.0
    var widgetOpacity = 1.0
    var clockX = 0.72
    var clockY = 0.20
    var onboarded = false
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
    func name(_ language: String) -> String { language == "ar" ? name_ar : name_en }
    static let builtin = Theme(id: "spirit-of-the-uae", name_ar: "روح الإمارات", name_en: "Spirit of the UAE", version: 1, timezone: "Asia/Dubai", slots: [ThemeSlot(period:"dawn",start:300,end:420), ThemeSlot(period:"morning",start:420,end:1020), ThemeSlot(period:"sunset",start:1020,end:1140), ThemeSlot(period:"night",start:1140,end:300)], widgets: ["clock":true,"date":true,"greeting":true,"weather":true,"prayer":true,"adhkar":true,"allow_move":true,"allow_resize":true], music_mode:"all",music_ids:[],assets:[])
}
struct Track: Codable, Identifiable {let id: String;let name_ar: String;let name_en: String;let url: String}
struct Catalog: Codable {let themes:[Theme];let music:[Track];let default_theme:String?}
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
        return greeting + (value.isEmpty ? "" : (language == "ar" ? "، " : ", ") + value)
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
