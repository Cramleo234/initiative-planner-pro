import Foundation
import AppKit

/// Verwaltet zwischengespeicherte Monster-Tokens als PNG im Application-Support-
/// Verzeichnis der App (`…/InitiativePlannerProMac/Tokens/<id>.png`).
///
/// Der Speicherzustand (`planner-state.json`) bleibt dadurch schlank: dort steht nur
/// der Token-Dateiname pro Monster, das Bild selbst liegt hier im Cache. Bilder werden
/// beim Import einmal dekodiert (webp/png/jpg), herunterskaliert und als PNG abgelegt.
public final class TokenStore: @unchecked Sendable {
    public static let shared = TokenStore()

    private let dir: URL
    private let lock = NSLock()
    private var memoryCache: [String: NSImage] = [:]
    /// Reicht für den ~72 pt großen Ring-Token auch auf Retina/Beamer.
    private let maxSide: CGFloat = 256

    private init() {
        self.dir = Self.resolveBaseDirectory(subfolder: "Tokens")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// Unter XCTest (`XCTestConfigurationFilePath` wird von Xcode für jeden Testlauf
    /// gesetzt) landen Zwischenablagen NIE im echten Application-Support-Ordner des
    /// Nutzers, sondern in einem Tmp-Verzeichnis. Ohne diese Weiche schreiben/löschen
    /// Tests direkt im echten Token-Cache der installierten App.
    static func resolveBaseDirectory(subfolder: String) -> URL {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("InitiativePlannerProMacTests", isDirectory: true)
                .appendingPathComponent(subfolder, isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("InitiativePlannerProMac", isDirectory: true)
            .appendingPathComponent(subfolder, isDirectory: true)
    }

    private func url(for id: String) -> URL {
        let safe = id.replacingOccurrences(of: "/", with: "_")
        return dir.appendingPathComponent(safe + ".png")
    }

    public func hasToken(_ id: String?) -> Bool {
        guard let id, !id.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: url(for: id).path)
    }

    /// Lädt (und cached) das Token-Bild eines Monsters, falls vorhanden.
    public func image(for id: String?) -> NSImage? {
        guard let id, !id.isEmpty else { return nil }
        lock.lock(); let cached = memoryCache[id]; lock.unlock()
        if let cached { return cached }
        let u = url(for: id)
        guard FileManager.default.fileExists(atPath: u.path), let img = NSImage(contentsOf: u) else { return nil }
        lock.lock(); memoryCache[id] = img; lock.unlock()
        return img
    }

    /// Stellt sicher, dass eine Datei tatsächlich lokal vorliegt.
    ///
    /// Token-Bilder liegen typischerweise in einem iCloud-synchronisierten Obsidian-Vault.
    /// Dort sind Dateien oft nur Platzhalter ("notDownloaded"): sie erscheinen im Finder
    /// mit korrekter Größe, ein Lesezugriff blockiert aber im read()-Syscall, bis iCloud
    /// die Daten nachgeladen hat — teilweise minutenlang oder bis zum Fehlschlag.
    /// Deshalb wird der Download hier explizit angefordert und begrenzt abgewartet.
    /// Gibt `false` zurück, wenn die Datei nicht rechtzeitig verfügbar wird.
    public func ensureLocallyAvailable(_ url: URL, timeout: TimeInterval = 25) -> Bool {
        func status(_ u: URL) -> URLUbiquitousItemDownloadingStatus? {
            // Bewusst frische URL: resourceValues cachen sonst den alten Status.
            try? URL(fileURLWithPath: u.path)
                .resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                .ubiquitousItemDownloadingStatus
        }
        // Kein iCloud-Item (normale lokale Datei) → direkt lesbar.
        guard let current = status(url) else { return true }
        if current == .current || current == .downloaded { return true }

        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.2)
            if let s = status(url), s == .current || s == .downloaded { return true }
        }
        return false
    }

    /// Dekodiert das Bild an `source` (webp/png/jpg), skaliert es herunter und legt es
    /// als PNG unter der Monster-ID ab. Gibt `true` bei Erfolg zurück.
    @discardableResult
    public func store(imageAt source: URL, for id: String) -> Bool {
        guard ensureLocallyAvailable(source) else { return false }
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

    /// Entfernt ein einzelnes Token aus dem Cache.
    public func remove(_ id: String) {
        lock.lock(); memoryCache[id] = nil; lock.unlock()
        try? FileManager.default.removeItem(at: url(for: id))
    }

    /// Löscht den gesamten Token-Cache (z. B. beim Leeren der Datenbank).
    public func removeAll() {
        lock.lock(); memoryCache.removeAll(); lock.unlock()
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}
