import Foundation
import Combine

struct AuthUser:Codable {let id:String;let email:String?}
struct AuthSession:Codable {let access_token:String;let refresh_token:String;let expires_at:Double?;let user:AuthUser}
struct CloudProfile:Codable {let user_id:String;let display_name:String;let language:String;let city:String;let preferences:Preferences}
enum WudError:LocalizedError {case message(String);var errorDescription:String?{if case .message(let s)=self{return s};return nil}}
@MainActor final class CloudClient:ObservableObject {
    static let shared=CloudClient()
    @Published private(set) var session:AuthSession?
    private var refreshTask:Task<Void,Error>?
    init(){if let d=SecureStore.load("auth-session"){session=try? JSONDecoder().decode(AuthSession.self,from:d)}}
    func request(_ path:String,method:String="GET",body:Data?=nil,authenticated:Bool=false,extra:[String:String]=[:])async throws->Data {
        guard AppConfiguration.configured,let url=URL(string:AppConfiguration.supabaseURL+path)else{throw WudError.message("Cloud service is not configured / الخدمة السحابية غير مهيأة")}
        if authenticated {try await refreshIfNeeded()}
        var r=URLRequest(url:url);r.httpMethod=method;r.timeoutInterval=25;r.httpBody=body;r.setValue(AppConfiguration.publishableKey,forHTTPHeaderField:"apikey");r.setValue("application/json",forHTTPHeaderField:"Content-Type")
        if authenticated {guard let s=session else{throw WudError.message("Please sign in / يرجى تسجيل الدخول")};r.setValue("Bearer \(s.access_token)",forHTTPHeaderField:"Authorization")}
        for(k,v)in extra{r.setValue(v,forHTTPHeaderField:k)}
        let(d,response)=try await URLSession.shared.data(for:r);guard let h=response as? HTTPURLResponse,(200..<300).contains(h.statusCode)else{let obj=(try? JSONSerialization.jsonObject(with:d)) as? [String:Any];throw WudError.message(obj?["msg"] as? String ?? obj?["message"] as? String ?? obj?["error_description"] as? String ?? "Request failed / تعذر إتمام الطلب")};return d
    }
    private func keep(_ s:AuthSession)throws{try SecureStore.save(JSONEncoder().encode(s),key:"auth-session");session=s}
    func signIn(email:String,password:String)async throws {let body=try JSONSerialization.data(withJSONObject:["email":email,"password":password]);let d=try await request("/auth/v1/token?grant_type=password",method:"POST",body:body);try keep(JSONDecoder().decode(AuthSession.self,from:d))}
    func signUp(email:String,password:String)async throws {let b=try JSONSerialization.data(withJSONObject:["email":email,"password":password]);_=try await request("/auth/v1/signup",method:"POST",body:b)}
    func recover(email:String)async throws {let b=try JSONSerialization.data(withJSONObject:["email":email]);_=try await request("/auth/v1/recover",method:"POST",body:b)}
    func refreshIfNeeded()async throws {
        guard let s=session else{throw WudError.message("Please sign in / يرجى تسجيل الدخول")}
        if (s.expires_at ?? 0)>Date().timeIntervalSince1970+60{return}
        if let task=refreshTask{return try await task.value}
        let task=Task {let b=try JSONSerialization.data(withJSONObject:["refresh_token":s.refresh_token]);let d=try await self.request("/auth/v1/token?grant_type=refresh_token",method:"POST",body:b);try self.keep(JSONDecoder().decode(AuthSession.self,from:d))};refreshTask=task
        defer{refreshTask=nil};try await task.value
    }
    func signOut()async {if session != nil{_=try? await request("/auth/v1/logout",method:"POST",authenticated:true)};SecureStore.remove("auth-session");session=nil}
    func deleteAccount()async throws {let b=try JSONSerialization.data(withJSONObject:["confirmation":"DELETE"]);_=try await request("/functions/v1/delete-account",method:"POST",body:b,authenticated:true);SecureStore.remove("auth-session");session=nil}
    func saveProfile(_ p:Preferences)async throws {guard let s=session else{return};let value=CloudProfile(user_id:s.user.id,display_name:p.name,language:p.language,city:p.city,preferences:p);_=try await request("/rest/v1/profiles?on_conflict=user_id",method:"POST",body:JSONEncoder().encode(value),authenticated:true,extra:["Prefer":"resolution=merge-duplicates"])}
    func profile()async throws->Preferences? {guard let s=session else{return nil};let d=try await request("/rest/v1/profiles?user_id=eq.\(s.user.id)&select=*",authenticated:true);return try JSONDecoder().decode([CloudProfile].self,from:d).first?.preferences}
    func catalog()async throws->Catalog {let d=try await request("/functions/v1/catalog");return try JSONDecoder().decode(Catalog.self,from:d)}
    func inbox()async throws->[InboxMessage] {let d=try await request("/rest/v1/messages?select=id,title_ar,title_en,body_ar,body_en&order=starts_at.desc",authenticated:true);return try JSONDecoder().decode([InboxMessage].self,from:d)}
}
