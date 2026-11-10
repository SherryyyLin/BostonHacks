// Run from the project root: swift scripts/generate_icon.swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let colorSpace = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: 1024, height: 1024,
                        bitsPerComponent: 8, bytesPerRow: 1024 * 4,
                        space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let dark = CGColor(red: 17 / 255, green: 47 / 255, blue: 43 / 255, alpha: 1)
let mint = CGColor(red: 164 / 255, green: 239 / 255, blue: 203 / 255, alpha: 1)
context.setFillColor(dark)
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
context.setStrokeColor(mint)
context.setLineWidth(25)
let frame = CGPath(roundedRect: CGRect(x: 154, y: 202, width: 716, height: 620),
                   cornerWidth: 84, cornerHeight: 84, transform: nil)
context.addPath(frame)
context.strokePath()
context.setLineWidth(18)
context.move(to: CGPoint(x: 154, y: 666))
context.addLine(to: CGPoint(x: 870, y: 666))
context.strokePath()
context.setFillColor(mint)
for x in [235, 295, 355] {
    context.fillEllipse(in: CGRect(x: x - 12, y: 732, width: 24, height: 24))
}
context.setLineWidth(43)
context.setLineJoin(.round)
context.move(to: CGPoint(x: 285, y: 569))
context.addLine(to: CGPoint(x: 423, y: 461))
context.addLine(to: CGPoint(x: 285, y: 352))
context.strokePath()
context.move(to: CGPoint(x: 504, y: 350))
context.addLine(to: CGPoint(x: 706, y: 350))
context.strokePath()
let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination))
print(output.path)
