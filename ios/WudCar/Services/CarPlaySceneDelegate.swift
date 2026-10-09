import CarPlay

// Activate this scene only with Apple's granted CarPlay Audio entitlement.
// A template app cannot replace the vehicle dashboard or expose arbitrary websites.
@MainActor final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var controller: CPInterfaceController?
    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        controller = interfaceController
        Task { await AppState.shared.refresh(); showHome() }
    }
    private func showHome() {
        let state = AppState.shared
        let title = WudDomain.greeting(name: state.preferences.name, hour: Calendar.current.component(.hour, from: Date()), language: state.preferences.language)
        let entertainment = CPListItem(text: state.text("الترفيه", "Entertainment"), detailText: state.text("قائمة الثيم والمصادر الصوتية", "Theme playlist and audio sources"), image: UIImage(systemName: "play.circle.fill"))
        entertainment.handler = { [weak self] _, completion in self?.showAudio(); completion() }
        let list = CPListTemplate(title: title, sections: [CPListSection(items: [entertainment])])
        controller?.setRootTemplate(list, animated: false, completion: nil)
    }
    private func showAudio() {
        let state = AppState.shared
        let tracks = state.tracks.filter { state.theme.music_mode == "all" || (state.theme.music_mode == "selected" && state.theme.music_ids.contains($0.id)) }
        var items = tracks.map { track in audioItem(name: state.text(track.name_ar, track.name_en), url: WudDomain.validURL(track.url)) }
        items += state.sources.filter { $0.mediaKind == "audio" && $0.type != "website" && $0.type != "playlist" }.map { source in audioItem(name: source.name, url: source.type == "local" ? LocalFiles.root.appendingPathComponent("Media").appendingPathComponent(source.url) : WudDomain.validURL(source.url)) }
        let list = CPListTemplate(title: state.text("الترفيه", "Entertainment"), sections: [CPListSection(items: items)])
        list.emptyViewTitleVariants = [state.text("لا توجد مقاطع في القائمة", "No tracks in this playlist")]
        controller?.pushTemplate(list, animated: true, completion: nil)
    }
    private func audioItem(name: String, url: URL?) -> CPListItem {
        let item = CPListItem(text: name, detailText: nil)
        item.handler = { [weak self] _, completion in defer { completion() }; if let url { PlayerService.shared.play(url: url, name: name); self?.controller?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil) } }
        return item
    }
    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) { controller = nil }
}
