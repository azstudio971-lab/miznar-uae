import SwiftUI

struct WidgetSettingsView:View {
    @EnvironmentObject var state:AppState
    private let names=["clock":("الساعة","Clock"),"date":("التاريخ","Date"),"greeting":("التحية","Greeting"),"weather":("الطقس","Weather"),"prayer":("الصلاة","Prayer"),"adhkar":("الأذكار","Remembrance"),"music":("الموسيقى","Music")]
    var body:some View {
        Form {
            Section { Text(state.theme.name(state.preferences.language));Toggle(state.text("تفعيل الموسيقى الاختيارية", "Enable optional music"),isOn:$state.preferences.musicEnabled) }
            ForEach(["clock","date","greeting","weather","prayer","adhkar","music"],id:\.self) { id in
                let layout=state.theme.widget(id)
                let key=state.theme.id+":"+id
                let title=names[id] ?? (id,id)
                if layout.visible { Section(state.text(title.0,title.1)) {
                    if layout.allow_hide { Toggle(state.text("إظهار", "Show"),isOn:Binding(get:{!value(key,layout).hidden},set:{var item=value(key,layout);item.hidden = !$0;state.preferences.widgetOverrides[key]=item})) }
                    if layout.allow_resize { Text(state.text("الحجم", "Size"));Slider(value:Binding(get:{value(key,layout).scale},set:{var item=value(key,layout);item.scale=$0;state.preferences.widgetOverrides[key]=item}),in:0.5...2) }
                    Text(state.text("الوضوح", "Opacity"));Slider(value:Binding(get:{value(key,layout).opacity},set:{var item=value(key,layout);item.opacity=$0;state.preferences.widgetOverrides[key]=item}),in:0.2...1)
                    Button(state.text("إعادة إعدادات الثيم", "Reset to theme defaults")) { state.preferences.widgetOverrides.removeValue(forKey:key) }
                } }
            }
            Section { NavigationLink(state.text("تحريك الأدوات في المعاينة", "Move widgets in preview")) { CarPreviewView() };Button(state.text("حفظ ومزامنة", "Save and sync")) { Task { await state.sync() } } }
        }.navigationTitle(state.text("أدوات الثيم", "Theme widgets"))
    }
    private func value(_ key:String,_ layout:WidgetLayout)->WidgetCustomization { state.preferences.widgetOverrides[key] ?? WidgetCustomization(x:layout.x,y:layout.y,scale:layout.scale,opacity:layout.opacity,hidden:false) }
}
