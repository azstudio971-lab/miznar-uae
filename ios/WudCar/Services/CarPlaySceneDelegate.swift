import CarPlay
import Combine
import UIKit

// Audio-entitled CarPlay UI uses Apple's templates and vehicle input handling.
// General web/video rendering and a replacement dashboard are not enabled.
@MainActor final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var controller: CPInterfaceController?
    private var themeList: CPListTemplate?
    private var libraryList: CPListTemplate?
    private var favoritesList: CPListTemplate?
    private var subscriptions = Set<AnyCancellable>()

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        controller = interfaceController
        installTabs()
        Publishers.Merge(AppState.shared.objectWillChange, ThemeCache.shared.objectWillChange)
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] in self?.refreshLists() }
            .store(in: &subscriptions)
        PlayerService.shared.$error.compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] message in self?.showError(message) }
            .store(in: &subscriptions)
        Task { [weak self] in
            await AppState.shared.refresh()
            guard let self, self.controller === interfaceController else { return }
            self.refreshLists()
        }
    }

    private func installTabs() {
        let state = AppState.shared
        let theme = CPListTemplate(title: state.text("الترفيه", "Entertainment"), sections: [])
        theme.tabTitle = state.text("الترفيه", "Entertainment")
        theme.tabImage = UIImage(systemName: "play.circle")
        let library = CPListTemplate(title: state.text("مكتبتي", "My Library"), sections: [])
        library.tabTitle = state.text("مكتبتي", "My Library")
        library.tabImage = UIImage(systemName: "music.note.list")
        let favorites = CPListTemplate(title: state.text("المفضلة", "Favorites"), sections: [])
        favorites.tabTitle = state.text("المفضلة", "Favorites")
        favorites.tabImage = UIImage(systemName: "star")
        themeList = theme; libraryList = library; favoritesList = favorites
        refreshLists()
        controller?.setRootTemplate(CPTabBarTemplate(templates: [theme, library, favorites]), animated: false, completion: nil)
    }

    private var audioSources: [MediaSource] {
        let state = AppState.shared
        let catalog = state.library.filter { $0.kind == "audio" }.map {
            MediaSource(id: $0.id, name: $0.name(state.preferences.language), url: $0.url,
                        type: "stream", mediaKind: "audio", favorite: state.preferences.favoriteIDs.contains($0.id))
        }
        return (catalog + state.sources).filter {
            $0.mediaKind == "audio" && $0.type != "website" && $0.type != "playlist"
        }
    }

    private func refreshLists() {
        let state = AppState.shared
        let tracks = Array(state.themeTracks.prefix(CPListTemplate.maximumItemCount))
        let trackItems = tracks.map { track -> CPListItem in
            let item = CPListItem(text: state.text(track.name_ar, track.name_en), detailText: nil,
                                  image: UIImage(systemName: "music.note"))
            item.handler = { [weak self] _, completion in
                PlayerService.shared.playPlaylist(tracks, startingAt: track.id)
                self?.showNowPlaying()
                completion()
            }
            return item
        }
        themeList?.updateSections([CPListSection(items: trackItems)])
        themeList?.emptyViewTitleVariants = [state.text("لا توجد مقاطع في قائمة الثيم", "No tracks in this theme")]
        themeList?.emptyViewSubtitleVariants = [state.text("أضف مصادر صوتية إلى مكتبتي على الآيفون", "Add audio sources to My Library on iPhone")]
        let sources = audioSources
        libraryList?.updateSections([CPListSection(items: Array(sources.prefix(CPListTemplate.maximumItemCount)).map(audioItem))])
        libraryList?.emptyViewTitleVariants = [state.text("مكتبتك الصوتية فارغة", "Your audio library is empty")]
        libraryList?.emptyViewSubtitleVariants = [state.text("نظّم المصادر الصوتية من الآيفون", "Organize audio sources on iPhone")]
        favoritesList?.updateSections([CPListSection(items: Array(sources.filter(\.favorite).prefix(CPListTemplate.maximumItemCount)).map(audioItem))])
        favoritesList?.emptyViewTitleVariants = [state.text("لا توجد مصادر صوتية مفضلة", "No favorite audio sources")]
        favoritesList?.emptyViewSubtitleVariants = [state.text("اضغط النجمة بجانب المصدر على الآيفون", "Star a source on iPhone")]
        if #available(iOS 26.4, *) {
            let image = themeImage()
            let thumbnail = CPThumbnailImage(image: image, imageOverlay: nil, sportsOverlay: nil)
            let greeting = WudDomain.greeting(name: state.preferences.name,
                hour: Calendar.current.component(.hour, from: Date()), language: state.preferences.language)
            let header = CPListTemplateDetailsHeader(thumbnail: thumbnail,
                title: state.theme.name(state.preferences.language), subtitle: greeting, actionButtons: [])
            header.wantsAdaptiveBackgroundStyle = true
            themeList?.listHeader = header
        }
    }

    private func themeImage() -> UIImage {
        let theme = AppState.shared.theme
        let period = WudDomain.period(date: Date(), theme: theme)
        if let medium = theme.currentMedium(layout: "compact", date: Date()), medium.kind == "image",
           let url = ThemeCache.shared.cached(theme: theme, identifier: medium.id),
           let image = UIImage(contentsOfFile: url.path) { return thumbnail(image) }
        if let asset = theme.assets.first(where: { $0.layout == "compact" && $0.period == period && $0.kind == "image" }),
           let url = ThemeCache.shared.cached(theme: theme, identifier: asset.id),
           let image = UIImage(contentsOfFile: url.path) { return thumbnail(image) }
        if theme.id == Theme.builtin.id, let image = UIImage(named: "compact-" + period) { return thumbnail(image) }
        return UIImage(named: "BrandIcon") ?? UIImage(systemName: "music.note")!
    }

    private func thumbnail(_ image: UIImage) -> UIImage {
        let size = CGSize(width: 320, height: 180)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let ratio = max(size.width / image.size.width, size.height / image.size.height)
            let width = image.size.width * ratio, height = image.size.height * ratio
            image.draw(in: CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height))
        }
    }

    private func audioItem(_ source: MediaSource) -> CPListItem {
        let item = CPListItem(text: source.name, detailText: nil,
                              image: UIImage(systemName: source.favorite ? "star.fill" : "music.note"))
        item.handler = { [weak self] _, completion in
            defer { completion() }
            let url: URL?
            if source.type == "local" {
                let root = LocalFiles.root.appendingPathComponent("Media", isDirectory: true).standardizedFileURL
                let file = root.appendingPathComponent(source.url).standardizedFileURL
                url = file.path.hasPrefix(root.path + "/") && FileManager.default.fileExists(atPath: file.path) ? file : nil
            } else { url = WudDomain.validURL(source.url) }
            guard let url else { self?.showError(AppState.shared.text("المصدر غير متاح", "Source unavailable")); return }
            PlayerService.shared.play(url: url, name: source.name)
            self?.showNowPlaying()
        }
        return item
    }

    private func showNowPlaying() {
        guard let controller, controller.topTemplate !== CPNowPlayingTemplate.shared else { return }
        controller.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
    }

    private func showError(_ message: String) {
        guard let controller, controller.presentedTemplate == nil else { return }
        let action = CPAlertAction(title: AppState.shared.text("حسنًا", "OK"), style: .default) { [weak self] _ in
            self?.controller?.dismissTemplate(animated: true, completion: nil)
        }
        controller.presentTemplate(CPAlertTemplate(titleVariants: [message], actions: [action]), animated: true, completion: nil)
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        subscriptions.removeAll()
        controller = nil; themeList = nil; libraryList = nil; favoritesList = nil
    }
}
