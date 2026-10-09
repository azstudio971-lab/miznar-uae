import SwiftUI
import AVKit
import Combine

struct ThemeWidget: View {
    @EnvironmentObject var state: AppState
    @ObservedObject var information=InformationService.shared
    @ObservedObject var player=PlayerService.shared
    let id:String
    let date:Date
    let theme:Theme
    var body: some View {
        Group {
            switch id {
            case "clock":
                if state.preferences.clockStyle=="analog" { AnalogClock(date:date).frame(width:70,height:70) }
                else { Text(formatDate(date,pattern:state.preferences.uses24HourClock ? "HH:mm" : "h:mm a")).font(.system(size:28,weight:.light,design:.rounded)).monospacedDigit() }
            case "date":
                VStack(spacing:3) { Text(formatDate(date,pattern:"EEE, d MMM"));if state.preferences.showHijri { Text(formatDate(date,pattern:"d MMM yyyy",hijri:true)).font(.caption2) } }
            case "greeting": Text(WudDomain.greeting(name:state.preferences.name,hour:Calendar.current.component(.hour,from:date),language:state.preferences.language))
            case "weather":
                if let weather=information.weather,weather.city==state.preferences.city { VStack { Label("\(Int(weather.temperature.rounded()))°C",systemImage:weather.symbol);Text(weather.city).font(.caption2);if date.timeIntervalSince(weather.fetchedAt)>1800 { Text(state.text("محفوظ", "Cached")).font(.caption2) } } }
                else { Label(state.text("الطقس غير متاح", "Weather unavailable"),systemImage:"cloud") }
            case "prayer":
                if information.prayer?.city==state.preferences.city,information.prayer?.method==state.preferences.prayerMethod,let next=information.nextPrayer(at:date) { VStack { Text(state.text(prayerArabic(next.0),next.0));Text(next.1,style:.timer).monospacedDigit() } }
                else { Text(state.text("مواقيت الصلاة غير متاحة", "Prayer times unavailable")) }
            case "adhkar":
                if let item=state.religious.first { Text(state.text(item.text_ar,item.text_en)).lineLimit(2).frame(maxWidth:240) }
            case "music":
                if state.preferences.musicEnabled,theme.music_mode != "none",let track=state.tracks.first(where:{theme.music_mode=="all" || theme.music_ids.contains($0.id)}) {
                    Button { if player.title==track.name_en || player.title==track.name_ar { player.stop() } else if let url=WudDomain.validURL(track.url) { player.play(url:url,name:state.text(track.name_ar,track.name_en)) } } label: { Label(player.title.isEmpty ? state.text(track.name_ar,track.name_en) : player.title,systemImage:player.title.isEmpty ? "play.circle" : "stop.circle").lineLimit(1) }.buttonStyle(.plain)
                }
            default: EmptyView()
            }
        }.font(.caption).foregroundStyle(.white).shadow(color:.black.opacity(0.5),radius:4)
    }
    private func formatDate(_ date:Date,pattern:String,hijri:Bool=false)->String { let formatter=DateFormatter();formatter.locale=Locale(identifier:state.preferences.language);formatter.timeZone=TimeZone(identifier:theme.timezone);formatter.calendar=Calendar(identifier:hijri ? .islamicUmmAlQura : .gregorian);formatter.dateFormat=pattern;return formatter.string(from:date) }
    private func prayerArabic(_ key:String)->String { ["Fajr":"الفجر","Dhuhr":"الظهر","Asr":"العصر","Maghrib":"المغرب","Isha":"العشاء"][key] ?? key }
}
struct AnalogClock:View {
    let date:Date
    var body:some View {
        let components=Calendar.current.dateComponents([.hour,.minute],from:date)
        let minutes=Double(components.minute ?? 0),hours=Double((components.hour ?? 0)%12)+minutes/60
        ZStack { Circle().stroke(.white.opacity(0.7),lineWidth:1);ForEach(0..<12,id:\.self) { tick in Capsule().fill(.white).frame(width:2,height:5).offset(y:-30).rotationEffect(.degrees(Double(tick)*30)) };Capsule().fill(.white).frame(width:3,height:20).offset(y:-10).rotationEffect(.degrees(hours*30));Capsule().fill(.white).frame(width:2,height:28).offset(y:-14).rotationEffect(.degrees(minutes*6));Circle().fill(.white).frame(width:5,height:5) }.accessibilityLabel(date.formatted(date:.omitted,time:.shortened))
    }
}
@MainActor final class SilentThemePlayer:ObservableObject {
    let player=AVQueuePlayer()
    private var looper:AVPlayerLooper?
    func start(_ url:URL) { player.isMuted=true;player.allowsExternalPlayback=false;looper=AVPlayerLooper(player:player,templateItem:AVPlayerItem(url:url));player.play() }
    func stop() { player.pause();looper=nil;player.removeAllItems() }
}
struct SilentThemeVideo:View {
    let url:URL
    @StateObject private var playback=SilentThemePlayer()
    var body:some View { VideoPlayer(player:playback.player).disabled(true).allowsHitTesting(false).task(id:url) { playback.stop();playback.start(url) }.onDisappear { playback.stop() }.accessibilityHidden(true) }
}
