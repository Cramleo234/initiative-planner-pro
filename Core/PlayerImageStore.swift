import Foundation
import AppKit

/// Verwaltet Spielerbilder als PNG im Application-Support-Verzeichnis der App
/// (`…/InitiativePlannerProMac/PlayerImages/<uuid>.png`), UUID-versioniert und
/// bewusst getrennt vom Monster-Token-Zyklus (TokenStore): ein Leeren der
/// Monsterdatenbank darf Spielerbilder nie berühren. Bilder werden beim Ersetzen
/// oder Entfernen nie physisch gelöscht, damit Undo/Redo alte Versionen wiederherstellen kann.
public final class PlayerImageStore: @unchecked Sendable {
    public static let shared = PlayerImageStore()

    private let dir: URL
    private let lock = NSLock()
    private var memoryCache: [UUID: NSImage] = [:]
    private let maxSide: CGFloat = 256

    private init() {
        self.dir = TokenStore.resolveBaseDirectory(subfolder: "PlayerImages")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func url(for id: UUID) -> URL { dir.appendingPathComponent(id.uuidString + ".png") }

    /// Lädt (und cached) eine Spielerbildversion, falls vorhanden.
    public func image(for id: UUID?) -> NSImage? {
        guard let id else { return nil }
        lock.lock(); let cached = memoryCache[id]; lock.unlock()
        if let cached { return cached }
        let u = url(for: id)
        guard FileManager.default.fileExists(atPath: u.path), let img = NSImage(contentsOf: u) else { return nil }
        lock.lock(); memoryCache[id] = img; lock.unlock()
        return img
    }

    /// Dekodiert das Bild an `source`, skaliert es herunter und legt es unter der
    /// übergebenen (neuen) Bildversions-UUID ab. Gibt `true` bei Erfolg zurück.
    @discardableResult
    public func store(imageAt source: URL, as id: UUID) -> Bool {
        guard let img = NSImage(contentsOf: source) else { return false }
        return store(image: img, as: id)
    }

    /// Skaliert ein bereits dekodiertes Bild (z. B. Ergebnis des Bildausschnitt-Dialogs)
    /// herunter und legt es unter der übergebenen Bildversions-UUID ab.
    @discardableResult
    public func store(image: NSImage, as id: UUID) -> Bool {
        guard let png = downscaledImagePNG(image, maxSide: maxSide) else { return false }
        do {
            try png.write(to: url(for: id))
            lock.lock(); memoryCache[id] = NSImage(data: png); lock.unlock()
            return true
        } catch { return false }
    }
}
