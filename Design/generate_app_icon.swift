#!/usr/bin/env swift

import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let sizes = [16, 32, 64, 128, 256, 512, 1024]

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

guard CommandLine.arguments.count == 3 else {
    fail("usage: generate_app_icon.swift <source.svg> <output.appiconset>")
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true).standardizedFileURL

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fail("could not load SVG source at \(sourceURL.path)")
}

do {
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
} catch {
    fail("could not create output directory: \(error)")
}

for size in sizes {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
        fail("could not create \(size)x\(size) sRGB render context")
    }

    context.clear(CGRect(x: 0, y: 0, width: size, height: size))
    context.interpolationQuality = .high

    let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    sourceImage.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: .zero,
        operation: .sourceOver,
        fraction: 1.0,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let image = context.makeImage() else {
        fail("could not finalize \(size)x\(size) image")
    }

    let destinationURL = outputURL.appendingPathComponent("icon_\(size).png")
    guard let destination = CGImageDestinationCreateWithURL(
        destinationURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        fail("could not create PNG destination for \(destinationURL.path)")
    }

    // The CGImage carries the explicit sRGB color space from the render context.
    let properties: CFDictionary = [
        kCGImagePropertyDPIWidth: 72,
        kCGImagePropertyDPIHeight: 72
    ] as CFDictionary
    CGImageDestinationAddImage(destination, image, properties)

    guard CGImageDestinationFinalize(destination) else {
        fail("could not write \(destinationURL.path)")
    }

    print("wrote \(destinationURL.path) (\(size)x\(size), sRGB RGBA)")
}
