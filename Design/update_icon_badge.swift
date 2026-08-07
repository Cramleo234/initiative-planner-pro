#!/usr/bin/env swift
// Ersetzt den Versions-Badge (Pille unten am App-Icon) im 1024px-Master.
// Pillen-Geometrie wurde am 2026-08-07 einmalig visuell am 1.0.2-Icon kalibriert
// (Design/update_icon_badge.swift Historie) und bleibt seither stabil, solange
// sich das Grunddesign (goldener W20) nicht ändert.
import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 4 else {
    FileHandle.standardError.write(Data("usage: update_icon_badge.swift <source1024.png> <newVersionText> <output1024.png>\n".utf8))
    exit(1)
}
let srcURL = URL(fileURLWithPath: CommandLine.arguments[1])
let newText = CommandLine.arguments[2]
let outURL = URL(fileURLWithPath: CommandLine.arguments[3])

guard let baseImage = NSImage(contentsOf: srcURL) else {
    FileHandle.standardError.write(Data("error: could not load \(srcURL.path)\n".utf8)); exit(1)
}
let w = 1024, h = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()

// Referenzfarben aus dem bestehenden Icon (per Sichtprüfung kalibriert).
let borderColor = NSColor(calibratedRed: 0.75, green: 0.55, blue: 0.30, alpha: 1)
let fillColor = NSColor(calibratedRed: 0.16, green: 0.09, blue: 0.05, alpha: 1)
let textColor = NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.75, alpha: 1)

// Pillen-Außenkontur (AppKit-Koordinaten, unten-links-Ursprung): visuell kalibriert
// bei x[378,680] y[750,855] (oben-links) im 1024px-Master → gespiegelt für AppKit.
let visualRect = CGRect(x: 378, y: 750, width: 680 - 378, height: 855 - 750)
let pillRect = CGRect(x: visualRect.minX, y: CGFloat(h) - visualRect.maxY, width: visualRect.width, height: visualRect.height)

guard let outContext = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    FileHandle.standardError.write(Data("error: no context\n".utf8)); exit(1)
}
outContext.clear(CGRect(x: 0, y: 0, width: w, height: h))
outContext.interpolationQuality = .high
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: outContext, flipped: false)

baseImage.draw(in: NSRect(x: 0, y: 0, width: w, height: h), from: .zero, operation: .sourceOver, fraction: 1.0, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])

// Alte Pille komplett übermalen: Außenkontur (Rand) + eingerückte Füllung neu zeichnen.
let borderPath = NSBezierPath(roundedRect: pillRect, xRadius: pillRect.height / 2, yRadius: pillRect.height / 2)
borderColor.setFill()
borderPath.fill()
let inset: CGFloat = 6
let fillRect = pillRect.insetBy(dx: inset, dy: inset)
let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: fillRect.height / 2, yRadius: fillRect.height / 2)
fillColor.setFill()
fillPath.fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let fontSize = fillRect.height * 0.60
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
    .foregroundColor: textColor,
    .paragraphStyle: paragraph
]
let attrString = NSAttributedString(string: newText, attributes: attrs)
let textSize = attrString.size()
attrString.draw(at: CGPoint(x: fillRect.midX - textSize.width / 2, y: fillRect.midY - textSize.height / 2 - 2))

NSGraphicsContext.restoreGraphicsState()

guard let outImage = outContext.makeImage() else {
    FileHandle.standardError.write(Data("error: could not finalize image\n".utf8)); exit(1)
}
guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    FileHandle.standardError.write(Data("error: no destination\n".utf8)); exit(1)
}
CGImageDestinationAddImage(dest, outImage, [kCGImagePropertyDPIWidth: 72, kCGImagePropertyDPIHeight: 72] as CFDictionary)
guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write(Data("error: could not write \(outURL.path)\n".utf8)); exit(1)
}
print("wrote \(outURL.path)")
