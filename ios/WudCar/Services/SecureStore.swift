import Foundation
import Security

enum SecureStore {
    static func save(_ data:Data,key:String) throws {
        let q:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"com.azpixel.wudcar",kSecAttrAccount as String:key]
        SecItemDelete(q as CFDictionary)
        var n=q;n[kSecValueData as String]=data;n[kSecAttrAccessible as String]=kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status=SecItemAdd(n as CFDictionary,nil);guard status==errSecSuccess else{throw NSError(domain:NSOSStatusErrorDomain,code:Int(status))}
    }
    static func load(_ key:String)->Data? {let q:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"com.azpixel.wudcar",kSecAttrAccount as String:key,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne];var result:CFTypeRef?;guard SecItemCopyMatching(q as CFDictionary,&result)==errSecSuccess else{return nil};return result as? Data}
    static func remove(_ key:String){SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"com.azpixel.wudcar",kSecAttrAccount as String:key] as CFDictionary)}
}
enum LocalFiles {
    static var root:URL {let p=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("WudCar",isDirectory:true);try? FileManager.default.createDirectory(at:p,withIntermediateDirectories:true);return p}
    static func save<T:Encodable>(_ value:T,name:String)throws{try JSONEncoder().encode(value).write(to:root.appendingPathComponent(name),options:[.atomic,.completeFileProtection])}
    static func load<T:Decodable>(_ type:T.Type,name:String)->T? {guard let d=try? Data(contentsOf:root.appendingPathComponent(name))else{return nil};return try? JSONDecoder().decode(type,from:d)}
}
