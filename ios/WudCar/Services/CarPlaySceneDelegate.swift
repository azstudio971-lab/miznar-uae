import CarPlay

// Add com.apple.developer.carplay-audio only after Apple grants it.
@MainActor final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var controller: CPInterfaceController?
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        controller = interfaceController
        let state = AppState.shared
        let title = WudDomain.greeting(name: state.preferences.name, hour: Calendar.current.component(.hour, from: Date()), language: state.preferences.language)
        let items: [CPListItem] = state.sources.filter { $0.mediaKind == "audio" && $0.type != "playlist" }.map { source in
            let item = CPListItem(text: source.name, detailText: state.text("تشغيل الصوت", "Play audio"))
            item.handler = { [weak self] _, completion in
                defer { completion() }
                let url = source.type == "local" ? LocalFiles.root.appendingPathComponent("Media").appendingPathComponent(source.url) : WudDomain.validURL(source.url)
                if let url { PlayerService.shared.play(url: url, name: source.name); self?.controller?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil) }
            }; return item
        }
        let list = CPListTemplate(title: title, sections: [CPListSection(items: items)])
        list.emptyViewTitleVariants = [state.text("أضف مصادر الصوت من الهاتف", "Add audio sources on your iPhone")]
        list.emptyViewSubtitleVariants = [state.text("استخدم الهاتف عندما تكون السيارة متوقفة", "Use your phone while parked")]
        interfaceController.setRootTemplate(list, animated: false, completion: nil)
    }
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) { controller = nil }
}
