// Рисует иконку приложения: колокольчик с «волнами» на градиенте.
// SF Symbols в иконке использовать нельзя (лицензия Apple), поэтому всё нарисовано путями.
//
//   swift Scripts/make_app_icon.swift
//
// Результат: PushWakeUpDemo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024×1024, без прозрачности).

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let output = URL(fileURLWithPath: "PushWakeUpDemo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
// Без альфа-канала: App Store не принимает иконки с прозрачностью.
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

// Рисуем в координатах «сверху вниз», как в макете.
context.translateBy(x: 0, y: CGFloat(size))
context.scaleBy(x: 1, y: -1)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [red, green, blue, alpha])!
}

// Фон: индиго → синий по диагонали
let gradient = CGGradient(colorsSpace: colorSpace,
                          colors: [color(0.40, 0.33, 0.93), color(0.16, 0.47, 0.98)] as CFArray,
                          locations: [0, 1])!
context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size, y: size), options: [])

let white = color(1, 1, 1)
let center = CGPoint(x: 512, y: 500)

// «Волны» по бокам колокольчика — пуш «будит» приложение
context.setLineCap(.round)
for (radius, alpha) in [(255.0, 0.85), (330.0, 0.5)] {
    context.setStrokeColor(color(1, 1, 1, alpha))
    context.setLineWidth(36)
    for (start, end) in [(-0.55, 0.55), (Double.pi - 0.55, Double.pi + 0.55)] {
        context.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        context.strokePath()
    }
}

context.setFillColor(white)

// Купол колокольчика
let bell = CGMutablePath()
bell.move(to: CGPoint(x: 330, y: 655))
bell.addCurve(to: CGPoint(x: 372, y: 540), control1: CGPoint(x: 360, y: 625), control2: CGPoint(x: 372, y: 590))
bell.addLine(to: CGPoint(x: 372, y: 455))
bell.addCurve(to: CGPoint(x: 512, y: 300), control1: CGPoint(x: 372, y: 360), control2: CGPoint(x: 432, y: 300))
bell.addCurve(to: CGPoint(x: 652, y: 455), control1: CGPoint(x: 592, y: 300), control2: CGPoint(x: 652, y: 360))
bell.addLine(to: CGPoint(x: 652, y: 540))
bell.addCurve(to: CGPoint(x: 694, y: 655), control1: CGPoint(x: 652, y: 590), control2: CGPoint(x: 664, y: 625))
bell.closeSubpath()
context.addPath(bell)
context.fillPath()

// Нижний край
context.addPath(CGPath(roundedRect: CGRect(x: 310, y: 640, width: 404, height: 52), cornerWidth: 26, cornerHeight: 26, transform: nil))
context.fillPath()

// Ушко сверху и язычок снизу
context.fillEllipse(in: CGRect(x: 482, y: 252, width: 60, height: 60))
context.fillEllipse(in: CGRect(x: 462, y: 702, width: 100, height: 100))

let image = context.makeImage()!
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
CGImageDestinationFinalize(destination)
print("✅ \(output.path)")
