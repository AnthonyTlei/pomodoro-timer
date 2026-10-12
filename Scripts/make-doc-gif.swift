import Foundation
import ImageIO
import UniformTypeIdentifiers

// Encode native screenshot frames, retaining their measured capture cadence.
// Usage: swift Scripts/make-doc-gif.swift <frames-directory> <output.gif>
guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: make-doc-gif.swift <frames-directory> <output.gif>")
}
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let frames = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
let times = try JSONDecoder().decode([Double].self, from: Data(contentsOf: directory.appendingPathComponent("times.json")))
guard !frames.isEmpty, frames.count == times.count,
      let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, frames.count, nil)
else { fatalError("Expected numbered PNG frames and matching times.json") }
CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for (index, url) in frames.enumerated() {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1080
          ] as CFDictionary) else { fatalError("Cannot decode \(url.lastPathComponent)") }
    let delay = index == 0 ? 0.8 : index == frames.count - 1 ? 1.5 : max(0.03, times[index + 1] - times[index])
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay
    ]] as CFDictionary)
}
guard CGImageDestinationFinalize(destination) else { fatalError("Cannot write GIF") }
print("Encoded \(frames.count) native frames into \(output.lastPathComponent)")
