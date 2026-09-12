import AppKit

/// Skaliert ein Bild proportional auf `maxSide` herunter und liefert PNG-Daten mit
/// Alphakanal. Gemeinsam genutzt von `TokenStore` (Monster-Tokens) und
/// `PlayerImageStore` (Spielerbilder) — vorher zwei identische Kopien dieser Funktion.
///
/// Bewusst `image.size` statt der rohen Pixelmaße aus `tiffRepresentation`: Fotos mit
/// abweichender DPI-Metadaten (z. B. von Handykameras) haben eine `image.size`, die von
/// den rohen Pixelmaßen abweicht — genau der Koordinatenraum, den
/// `NSImage.draw(in:from:)` für die `from`-Rect erwartet. Wird stattdessen mit den rohen
/// Pixelmaßen gearbeitet, zeichnet Cocoa nur einen Teilausschnitt und lässt den Rest der
/// Zielfläche transparent.
func downscaledImagePNG(_ image: NSImage, maxSide: CGFloat) -> Data? {
    let size = image.size
    let w = size.width, h = size.height
    guard w > 0, h > 0 else { return nil }
    let scale = min(1, maxSide / max(w, h))
    let tw = max(1, Int(w * scale)), th = max(1, Int(h * scale))
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
