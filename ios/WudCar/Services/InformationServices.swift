import Foundation
import WeatherKit
import CoreLocation
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
    init(){weather=LocalFiles.load(WeatherSnapshot.self,name:"weather.json");prayer=LocalFiles.load(PrayerSnapshot.self,name:"prayer.json")}
    func refresh(city:String,method:Int)async {
        guard !refreshing,let region=City.all.first(where:{$0.name==city})else{return};refreshing=true;defer{refreshing=false}
        await updateWeather(region);await updatePrayer(region,method:method)
    }
    private func updateWeather(_ city:City)async {
        if let weather,weather.city==city.name,Date().timeIntervalSince(weather.fetchedAt)<1800{return}
        do {
            let result=try await WeatherService.shared.weather(for:CLLocation(latitude:city.lat,longitude:city.lon))
            let attribution=try await WeatherService.shared.attribution
            var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(identifier:"Asia/Dubai")!
            let tomorrow=result.dailyForecast.first{calendar.isDateInTomorrow($0.date)}
            let snapshot=WeatherSnapshot(city:city.name,temperature:result.currentWeather.temperature.converted(to:.celsius).value,symbol:result.currentWeather.symbolName,tomorrowLow:tomorrow?.lowTemperature.converted(to:.celsius).value,tomorrowHigh:tomorrow?.highTemperature.converted(to:.celsius).value,fetchedAt:Date(),attributionURL:attribution.legalPageURL.absoluteString,attributionMark:attribution.combinedMarkDarkURL.absoluteString)
            weather=snapshot;weatherError=nil;try? LocalFiles.save(snapshot,name:"weather.json")
        }catch{weatherError="Weather is unavailable. Cached data is shown when available. / الطقس غير متاح؛ تظهر آخر نتيجة محفوظة عند توفرها."}
    }
    private func updatePrayer(_ city:City,method:Int)async {
        let formatter=DateFormatter();formatter.dateFormat="dd-MM-yyyy";formatter.locale=Locale(identifier:"en_US_POSIX");formatter.timeZone=TimeZone(identifier:"Asia/Dubai");let day=formatter.string(from:Date())
        if let prayer,prayer.city==city.name,prayer.method==method,prayer.day==day{return}
        guard [3,4,8,16].contains(method)else{return}
        var components=URLComponents(string:"https://api.aladhan.com/v1/timings/\(day)")!;components.queryItems=[URLQueryItem(name:"latitude",value:String(city.lat)),URLQueryItem(name:"longitude",value:String(city.lon)),URLQueryItem(name:"method",value:String(method)),URLQueryItem(name:"timezonestring",value:"Asia/Dubai")]
        do {var request=URLRequest(url:components.url!);request.timeoutInterval=20;let(data,response)=try await URLSession.shared.data(for:request);guard let http=response as? HTTPURLResponse,(200..<300).contains(http.statusCode),let root=(try JSONSerialization.jsonObject(with:data)) as? [String:Any],let value=root["data"] as? [String:Any],let times=value["timings"] as? [String:String]else{throw WudError.message("Prayer response invalid")};let snapshot=PrayerSnapshot(city:city.name,method:method,day:day,timezone:"Asia/Dubai",timings:times.mapValues{String($0.prefix(5))},fetchedAt:Date());prayer=snapshot;prayerError=nil;try? LocalFiles.save(snapshot,name:"prayer.json")}
        catch{prayerError="Prayer data is unavailable. Check the date of cached information. / بيانات الصلاة غير متاحة؛ تحقق من تاريخ آخر نتيجة محفوظة."}
    }
    func nextPrayer(at date:Date)->(String,Date)? {
        guard let prayer else{return nil};let formatter=DateFormatter();formatter.locale=Locale(identifier:"en_US_POSIX");formatter.timeZone=TimeZone(identifier:prayer.timezone);formatter.dateFormat="dd-MM-yyyy HH:mm"
        return ["Fajr","Dhuhr","Asr","Maghrib","Isha"].compactMap{key->(String,Date)? in guard let value=prayer.timings[key],let time=formatter.date(from:prayer.day+" "+value),time>date else{return nil};return(key,time)}.min{$0.1<$1.1}
    }
}
