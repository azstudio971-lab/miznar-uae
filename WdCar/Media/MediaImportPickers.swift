import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct MediaDocumentPicker: UIViewControllerRepresentable {
    var folders = false
    let completion: ([URL]) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let m4a = UTType(filenameExtension: "m4a") ?? .audio
        let mp3 = UTType(filenameExtension: "mp3") ?? .audio
        let formats = ["mkv", "avi", "webm", "flac", "ogg", "ac3", "dts", "ts"].compactMap { UTType(filenameExtension: $0) }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: folders ? [.folder] : [.movie, .audio, .mpeg4Movie, .quickTimeMovie, mp3, m4a] + formats, asCopy: false)
        picker.allowsMultipleSelection = true; picker.delegate = context.coordinator; return picker
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: ([URL]) -> Void
        init(completion: @escaping ([URL]) -> Void) { self.completion = completion }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { completion(urls) }
    }
}
struct MediaPhotosPicker: UIViewControllerRepresentable {
    let completion: ([URL], [String]) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(); configuration.filter = .videos; configuration.selectionLimit = 0
        let picker = PHPickerViewController(configuration: configuration); picker.delegate = context.coordinator; return picker
    }
    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let completion: ([URL], [String]) -> Void
        init(completion: @escaping ([URL], [String]) -> Void) { self.completion = completion }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            let group = DispatchGroup(); let lock = NSLock(); var files: [Int: URL] = [:]; var errors: [String] = []
            for (index, result) in results.enumerated() {
                group.enter()
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    defer { group.leave() }
                    do {
                        guard let url else { throw error ?? MediaImportError.unsupported }
                        let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
                        try FileManager.default.copyItem(at: url, to: copy)
                        lock.lock(); files[index] = copy; lock.unlock()
                    } catch { lock.lock(); errors.append(error.localizedDescription); lock.unlock() }
                }
            }
            group.notify(queue: .main) { self.completion(files.keys.sorted().compactMap { files[$0] }, errors) }
        }
    }
}
