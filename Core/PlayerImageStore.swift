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
        guard let img = NSImage(contentsOf: source), let png = downscaledPNG(img) else { return false }
        do {
            try png.write(to: url(for: id))
            lock.lock(); memoryCache[id] = NSImage(data: png); lock.unlock()
            return true
        } catch { return false }
    }

    private func downscaledPNG(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        let w = rep.pixelsWide, h = rep.pixelsHigh
        guard w > 0, h > 0 else { return nil }
        let scale = min(1, maxSide / CGFloat(max(w, h)))
        let tw = max(1, Int(CGFloat(w) * scale)), th = max(1, Int(CGFloat(h) * scale))
        guard let out = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: tw, pixelsHigh: th,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        out.size = NSSize(width: tw, height: th)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
        image.draw(in: NSRect(x: 0, y: 0, width: tw, height: th),
                   from: NSRect(x: 0, y: 0, width: w, height: h),
                   operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return out.representation(using: .png, properties: [:])
    }
}
