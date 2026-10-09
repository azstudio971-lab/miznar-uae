import Foundation
import Combine

struct WeatherSnapshot:Codable {let city:String;let temperature:Double;let symbol:String;let tomorrowLow:Double?;let tomorrowHigh:Double?;let fetchedAt:Date;let attributionURL:String;let attributionMark:String}
struct PrayerSnapshot:Codable {let city:String;let method:Int;let day:String;let timezone:String;let timings:[String:String];let fetchedAt:Date}
@MainActor final class InformationService:ObservableObject {
    static let shared=InformationService()
    @Published var weather:WeatherSnapshot?
    @Published var prayer:PrayerSnapshot?
    @Published var weatherError:String?
    @Published var prayerError:String?
    @Published var refreshing=false
    private var lastKey=""
    private var lastFetch=Date.distantPast
    init(){weather=LocalFiles.load(WeatherSnapshot.self,name:"weather.json");prayer=LocalFiles.load(PrayerSnapshot.self,name:"prayer.json")}
    func refresh(city:String,method:Int)async {
        guard !refreshing else{return}
        let prefs=AppState.shared.preferences
        let region=City.all.first(where:{$0.name==city}) ?? City.all[0]
        let lat=prefs.locationMode=="auto" ? (prefs.latitude ?? region.lat) : region.lat
        let lon=prefs.locationMode=="auto" ? (prefs.longitude ?? region.lon) : region.lon
        let key="\(lat),\(lon),\(method),\(prefs.timezone)"
        if key==lastKey && Date().timeIntervalSince(lastFetch)<600{return}
        refreshing=true;defer{refreshing=false}
        do {
            var c=URLComponents();c.queryItems=[URLQueryItem(name:"lat",value:String(lat)),URLQueryItem(name:"lon",value:String(lon)),URLQueryItem(name:"method",value:String(method)),URLQueryItem(name:"timezone",value:prefs.timezone)]
            let d=try await CloudClient.shared.request("/functions/v1/location-info?"+(c.percentEncodedQuery ?? ""))
            struct Reply:Decodable {struct Weather:Decodable{let temperature:Double;let symbol:String};let weather:Weather?;let prayer:[String:String]?;let day:String;let timezone:String}
            let result=try JSONDecoder().decode(Reply.self,from:d)
            if let w=result.weather {weather=WeatherSnapshot(city:city,temperature:w.temperature,symbol:w.symbol.contains("rain") ? "cloud.rain" : w.symbol.contains("cloud") ? "cloud.sun" : "sun.max",tomorrowLow:nil,tomorrowHigh:nil,fetchedAt:Date(),attributionURL:"https://www.met.no/",attributionMark:"");try? LocalFiles.save(weather,name:"weather.json");weatherError=nil} else {weather=nil;weatherError="الطقس غير متاح حالياً / Weather unavailable"}
            if let times=result.prayer {prayer=PrayerSnapshot(city:city,method:method,day:result.day,timezone:result.timezone,timings:times,fetchedAt:Date());try? LocalFiles.save(prayer,name:"prayer.json");prayerError=nil} else {prayer=nil;prayerError="مواقيت الصلاة غير متاحة / Prayer times unavailable"}
            lastKey=key;lastFetch=Date()
        }catch{weatherError=error.localizedDescription;prayerError=error.localizedDescription}
    }
    func nextPrayer(at date:Date)->(String,Date)? {
        guard let prayer else{return nil};let formatter=DateFormatter();formatter.locale=Locale(identifier:"en_US_POSIX");formatter.timeZone=TimeZone(identifier:prayer.timezone);formatter.dateFormat="dd-MM-yyyy HH:mm"
        return ["Fajr","Dhuhr","Asr","Maghrib","Isha"].compactMap{key->(String,Date)? in guard let value=prayer.timings[key],let time=formatter.date(from:prayer.day+" "+value),time>date else{return nil};return(key,time)}.min{$0.1<$1.1}
    }
}
