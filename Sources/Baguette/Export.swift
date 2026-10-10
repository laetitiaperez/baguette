import AppKit
import UniformTypeIdentifiers
import WandCore

/// Export PNG : nom proposé et écriture du fichier.
enum Exporter {
    /// `<nom sans extension>-baguette.png` (ou `image-baguette.png` si aucun fichier n'est connu).
    static func suggestedName(for url: URL?) -> String {
        let stem = url?.deletingPathExtension().lastPathComponent ?? ""
        return (stem.isEmpty ? "image" : stem) + "-baguette.png"
    }

    /// Si un fichier existe déjà à cet endroit, propose « <nom> 2.png », « <nom> 3.png »…
    static func uniqueURL(for url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }
        let dir = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var n = 2
        while true {
            let candidate = dir.appendingPathComponent("\(stem) \(n)").appendingPathExtension(ext)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            n += 1
        }
    }

    /// Écrit l'image en PNG (sRGB, alpha droit) ; remplace un fichier existant.
    static func write(_ image: RGBAImage, to url: URL) throws {
        try ImageFile.pngData(image).write(to: url, options: .atomic)
    }
}

/// Promesse de fichier pour le glisser hors du canevas : le PNG n'est écrit que lorsque la destination
/// (Finder, autre app) le demande, à l'endroit qu'elle choisit.
final class PNGFilePromise: NSObject, NSFilePromiseProviderDelegate, Sendable {
    let image: RGBAImage
    let fileName: String
    /// Appelé sur le fil principal après une écriture réussie.
    let onWritten: @MainActor @Sendable () -> Void
    /// Appelé sur le fil principal si l'écriture échoue.
    let onFailure: @MainActor @Sendable (any Error) -> Void

    private static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()

    init(image: RGBAImage, fileName: String,
         onWritten: @escaping @MainActor @Sendable () -> Void,
         onFailure: @escaping @MainActor @Sendable (any Error) -> Void) {
        self.image = image
        self.fileName = fileName
        self.onWritten = onWritten
        self.onFailure = onFailure
    }

    /// Fournisseur à placer dans un `NSDraggingItem`.
    func makeProvider() -> NSFilePromiseProvider {
        NSFilePromiseProvider(fileType: UTType.png.identifier, delegate: self)
    }

    func filePromiseProvider(_ provider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        fileName
    }

    func operationQueue(for provider: NSFilePromiseProvider) -> OperationQueue {
        Self.queue
    }

    func filePromiseProvider(_ provider: NSFilePromiseProvider, writePromiseTo url: URL,
                             completionHandler: @escaping ((any Error)?) -> Void) {
        do {
            try Exporter.write(image, to: Exporter.uniqueURL(for: url))
            completionHandler(nil)
            Task { @MainActor in onWritten() }
        } catch {
            completionHandler(error)
            Task { @MainActor in onFailure(error) }
        }
    }
}
