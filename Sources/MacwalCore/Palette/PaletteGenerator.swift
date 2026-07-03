import CoreGraphics
import Foundation
import ImageIO

public struct PaletteGenerator: Sendable {
    private let dateProvider: @Sendable () -> Date

    public init(dateProvider: @escaping @Sendable () -> Date = Date.init) {
        self.dateProvider = dateProvider
    }

    public func generate(from imageURL: URL, source: PaletteSource, config: MacwalConfig.PaletteConfig = .default) throws -> PaletteDocument {
        let pixels = try loadPixels(from: imageURL)
        guard !pixels.isEmpty else {
            throw MacwalError.paletteGenerationFailed("Image did not produce any readable pixels: \(imageURL.path)")
        }

        let average = averageColor(pixels)
        let wallpaperLuminance = average.perceivedLuminance
        let mode: String
        switch config.mode {
        case "dark", "light":
            mode = config.mode
        default:
            mode = wallpaperLuminance < 0.55 ? "dark" : "light"
        }

        let background: RGBColor
        let foregroundSeed: RGBColor
        if mode == "light" {
            background = average.mixed(with: .white, amount: 0.88)
            foregroundSeed = RGBColor(red: 17, green: 19, blue: 21)
        } else {
            background = average.mixed(with: .black, amount: 0.82)
            foregroundSeed = RGBColor(red: 246, green: 242, blue: 234)
        }

        let foreground = foregroundSeed.adjustedForContrast(
            against: background,
            minimum: config.minimumForegroundContrast
        )
        let accent = dominantAccent(from: pixels, fallback: average)
            .adjustedForContrast(against: background, minimum: config.minimumAccentContrast)

        let selectionSeed = accent.mixed(with: background, amount: mode == "light" ? 0.35 : 0.55)
        let selection = selectionSeed.adjustedForContrast(against: foreground, minimum: 3.0)

        var named: [String: RGBColor] = [
            "background": background,
            "foreground": foreground,
            "cursor": foreground,
            "selection": selection,
            "accent": accent,
            "accentAlt": accent.mixed(with: mode == "light" ? .black : .white, amount: 0.28),
            "black": background,
            "brightBlack": background.mixed(with: foreground, amount: 0.28),
            "white": foreground.mixed(with: background, amount: 0.08),
            "brightWhite": mode == "light" ? .black : .white
        ]

        let ansiSeeds: [(String, RGBColor)] = [
            ("red", RGBColor(red: 215, green: 82, blue: 82)),
            ("green", RGBColor(red: 112, green: 160, blue: 105)),
            ("yellow", RGBColor(red: 202, green: 164, blue: 74)),
            ("blue", RGBColor(red: 88, green: 139, blue: 202)),
            ("magenta", RGBColor(red: 176, green: 116, blue: 194)),
            ("cyan", accent),
            ("brightRed", RGBColor(red: 238, green: 112, blue: 112)),
            ("brightGreen", RGBColor(red: 144, green: 190, blue: 135)),
            ("brightYellow", RGBColor(red: 230, green: 199, blue: 108)),
            ("brightBlue", RGBColor(red: 126, green: 177, blue: 230)),
            ("brightMagenta", RGBColor(red: 204, green: 153, blue: 218)),
            ("brightCyan", accent.mixed(with: mode == "light" ? .black : .white, amount: 0.22))
        ]

        for (name, color) in ansiSeeds {
            named[name] = color.adjustedForContrast(against: background, minimum: 2.0)
        }

        let colors = named.mapValues(\.hex)
        let appearance = PaletteAppearance(
            recommendedMode: mode,
            wallpaperLuminance: round(wallpaperLuminance * 10_000) / 10_000,
            contrastValidated: validate(colors: named)
        )

        return PaletteDocument(
            generatedAt: Self.isoString(from: dateProvider()),
            source: source,
            appearance: appearance,
            colors: colors
        )
    }

    private func loadPixels(from imageURL: URL) throws -> [RGBColor] {
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw MacwalError.paletteGenerationFailed("Image does not exist: \(imageURL.path)")
        }

        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw MacwalError.paletteGenerationFailed("Could not read image: \(imageURL.path)")
        }

        let width = 96
        let height = 96
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        bytes.withUnsafeMutableBytes { rawBuffer in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return
            }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        var pixels: [RGBColor] = []
        pixels.reserveCapacity(width * height)
        for index in stride(from: 0, to: bytes.count, by: 4) {
            let alpha = bytes[index + 3]
            guard alpha > 12 else {
                continue
            }
            pixels.append(RGBColor(red: bytes[index], green: bytes[index + 1], blue: bytes[index + 2]))
        }

        return pixels
    }

    private func averageColor(_ pixels: [RGBColor]) -> RGBColor {
        var red = 0
        var green = 0
        var blue = 0
        for pixel in pixels {
            red += Int(pixel.red)
            green += Int(pixel.green)
            blue += Int(pixel.blue)
        }
        let count = max(1, pixels.count)
        return RGBColor(red: UInt8(red / count), green: UInt8(green / count), blue: UInt8(blue / count))
    }

    private func dominantAccent(from pixels: [RGBColor], fallback: RGBColor) -> RGBColor {
        struct Bucket {
            var count: Int
            var red: Int
            var green: Int
            var blue: Int
        }

        var buckets: [Int: Bucket] = [:]
        for pixel in pixels {
            let key = (Int(pixel.red / 16) << 8) | (Int(pixel.green / 16) << 4) | Int(pixel.blue / 16)
            var bucket = buckets[key] ?? Bucket(count: 0, red: 0, green: 0, blue: 0)
            bucket.count += 1
            bucket.red += Int(pixel.red)
            bucket.green += Int(pixel.green)
            bucket.blue += Int(pixel.blue)
            buckets[key] = bucket
        }

        let scored = buckets.values
            .map { bucket -> (Double, RGBColor) in
                let color = RGBColor(
                    red: UInt8(bucket.red / bucket.count),
                    green: UInt8(bucket.green / bucket.count),
                    blue: UInt8(bucket.blue / bucket.count)
                )
                let frequency = Double(bucket.count) / Double(max(1, pixels.count))
                let luminancePenalty = abs(color.perceivedLuminance - 0.52)
                let score = color.saturation * 2.2 + frequency * 0.9 - luminancePenalty
                return (score, color)
            }
            .sorted { left, right in
                if left.0 == right.0 {
                    return left.1.hex < right.1.hex
                }
                return left.0 > right.0
            }

        return scored.first?.1 ?? fallback
    }

    private func validate(colors: [String: RGBColor]) -> Bool {
        guard let background = colors["background"],
              let foreground = colors["foreground"],
              let selection = colors["selection"],
              let accent = colors["accent"],
              let brightWhite = colors["brightWhite"] else {
            return false
        }

        guard foreground.contrastRatio(against: background) >= 7.0,
              selection.contrastRatio(against: foreground) >= 3.0,
              accent.contrastRatio(against: background) >= 3.0,
              brightWhite.contrastRatio(against: background) >= 7.0 else {
            return false
        }

        for name in ["red", "green", "yellow", "blue", "magenta", "cyan", "white", "brightRed", "brightGreen", "brightYellow", "brightBlue", "brightMagenta", "brightCyan", "brightWhite"] {
            guard let color = colors[name], color.contrastRatio(against: background) >= 2.0 else {
                return false
            }
        }

        return true
    }

    private static func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
