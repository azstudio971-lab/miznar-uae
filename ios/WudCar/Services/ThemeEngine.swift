import Foundation
import CryptoKit
import Combine
import UIKit

extension Theme {
    func isAvailable(at date:Date)->Bool {
        let formatter=ISO8601DateFormatter()
        formatter.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        func parse(_ text:String)->Date? {if let value=formatter.date(from:text){return value};let plain=ISO8601DateFormatter();return plain.date(from:text)}
        if let start=starts_at,let d=parse(start),date<d{return false}
        if let end=ends_at,let d=parse(end),date>=d{return false}
        var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(identifier:timezone) ?? .current
        return (weekdays ?? [0,1,2,3,4,5,6]).contains(calendar.component(.weekday,from:date)-1)
    }
    func currentMedium(layout:String,date:Date)->ThemeMedium? {
        let period=WudDomain.period(date:date,theme:self)
        let options=(media ?? []).filter{$0.layout==layout&&($0.period==period||$0.period=="any")}.sorted{$0.sort_order<$1.sort_order}
        let total=options.reduce(0){$0+max(5,$1.duration_seconds)};guard total>0 else{return nil}
        var second=Int(date.timeIntervalSince1970)%total
        for item in options {let duration=max(5,item.duration_seconds);if second<duration{return item};second-=duration};return options.last
    }
    func widget(_ id:String)->WidgetLayout {
        if let configured=widget_settings?.first(where:{$0.widget_id==id}){return configured}
        let positions:[String:(Double,Double)]=["clock":(0.76,0.15),"date":(0.76,0.31),"greeting":(0.65,0.44),"weather":(0.2,0.16),"prayer":(0.2,0.4),"adhkar":(0.5,0.76),"music":(0.5,0.91)]
        let p=positions[id] ?? (0.5,0.5)
        return WidgetLayout(widget_id:id,visible:widgets[id] ?? false,x:p.0,y:p.1,scale:1,opacity:1,sort_order:0,allow_move:widgets["allow_move"] ?? false,allow_resize:widgets["allow_resize"] ?? true,allow_hide:true)
    }
}
@MainActor final class ThemeCache:ObservableObject {
    static let shared=ThemeCache()
    @Published var revision=0
    private let root=LocalFiles.root.appendingPathComponent("ThemeCache",isDirectory:true)
    private func file(theme:Theme,identifier:String)->URL {let key="\(theme.id)-\(theme.version)-\(identifier)";let hash=SHA256.hash(data:Data(key.utf8)).map{String(format:"%02x",$0)}.joined();return root.appendingPathComponent(hash)}
    func cached(theme:Theme,identifier:String)->URL? {let url=file(theme:theme,identifier:identifier);return FileManager.default.fileExists(atPath:url.path) ? url : nil}
    func prepare(theme:Theme)async {
        try? FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let assets=theme.assets.map{($0.id,$0.url,$0.kind)}+(theme.media ?? []).map{($0.id,$0.url,$0.kind)}
        for (identifier,address,kind) in assets {
            guard kind=="image",cached(theme:theme,identifier:identifier)==nil,let url=WudDomain.validURL(address),url.host==URL(string:AppConfiguration.supabaseURL)?.host else{continue}
            do {
                var request=URLRequest(url:url);request.timeoutInterval=20
                let (temporary,response)=try await URLSession.shared.download(for:request);defer{try? FileManager.default.removeItem(at:temporary)}
                guard let http=response as? HTTPURLResponse,(200..<300).contains(http.statusCode),let size=try temporary.resourceValues(forKeys:[.fileSizeKey]).fileSize,size<=10_000_000,let data=try? Data(contentsOf:temporary),UIImage(data:data) != nil else{continue}
                try data.write(to:file(theme:theme,identifier:identifier),options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication]);revision+=1
            }catch{continue}
        }
        trim()
    }
    private func trim(){guard let urls=try? FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:[.fileSizeKey,.contentModificationDateKey])else{return};let entries=urls.compactMap{url->(URL,Int,Date)? in guard let v=try? url.resourceValues(forKeys:[.fileSizeKey,.contentModificationDateKey])else{return nil};return (url,v.fileSize ?? 0,v.contentModificationDate ?? .distantPast)}.sorted{$0.2<$1.2};var total=entries.reduce(0){$0+$1.1};for entry in entries where total>80_000_000 {try? FileManager.default.removeItem(at:entry.0);total-=entry.1}}
}
