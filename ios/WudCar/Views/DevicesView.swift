import SwiftUI

struct DevicesView:View {
    @EnvironmentObject var state:AppState
    @State private var devices:[RegisteredDevice]=[]
    @State private var busy=false
    @State private var error:String?
    @State private var revoke:RegisteredDevice?
    @State private var signOutOthers=false
    var body:some View {
        List {
            Section {
                if busy { ProgressView() }
                if let error { Text(error).foregroundStyle(.red) }
                ForEach(devices) { device in VStack(alignment:.leading,spacing:6) {
                    HStack { Label(device.name,systemImage:"iphone");Spacer();if device.id.lowercased()==CloudClient.shared.deviceID.lowercased() { Text(state.text("هذا الجهاز", "This device")).font(.caption) } }
                    Text(state.text("آخر نشاط: ", "Last activity: ")+device.last_seen_at).font(.caption).foregroundStyle(.secondary)
                    if device.revoked_at != nil { Text(state.text("وصول الجهاز مُلغى", "Device access revoked")).font(.caption) }
                    else if device.id.lowercased() != CloudClient.shared.deviceID.lowercased() { Button(state.text("إلغاء وصول الجهاز", "Revoke device access"),role:.destructive) { revoke=device } }
                } }
                Button(state.text("تسجيل خروج الجلسات الأخرى", "Sign out other sessions"),role:.destructive) { signOutOthers=true }.disabled(busy)
            }
            Section { Text(state.text("إلغاء جهاز يمنع جلسات استخدامه المعتمدة على تسجيل الجهاز. تسجيل خروج الجلسات الأخرى يلغي صلاحية تحديث الدخول؛ قد تظل رموز الدخول الحالية صالحة حتى انتهاء مدتها.", "Device revocation blocks usage sessions that require device registration. Signing out other sessions revokes refresh access; existing access tokens may remain valid until expiry.")).font(.caption) }
        }.navigationTitle(state.text("الأجهزة والجلسات", "Devices and sessions")).task { await load() }.refreshable { await load() }
        .confirmationDialog(state.text("إلغاء وصول هذا الجهاز؟", "Revoke this device’s access?"),isPresented:Binding(get:{revoke != nil},set:{if !$0 {revoke=nil}})) { Button(state.text("إلغاء الوصول", "Revoke access"),role:.destructive) { guard let device=revoke else{return};run("revoke",id:device.id);revoke=nil } }
        .confirmationDialog(state.text("تسجيل خروج الجلسات الأخرى؟", "Sign out all other sessions?"),isPresented:$signOutOthers) { Button(state.text("تسجيل الخروج", "Sign out"),role:.destructive) { run("signout_others") } }
    }
    private func load()async { busy=true;defer{busy=false};do { devices=try await CloudClient.shared.devices();error=nil } catch { self.error=error.localizedDescription } }
    private func run(_ action:String,id:String?=nil) { Task { busy=true;do { _=try await CloudClient.shared.deviceAction(action,id:id);await load() } catch { self.error=error.localizedDescription;busy=false } } }
}
