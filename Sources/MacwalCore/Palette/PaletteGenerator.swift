import CoreGraphics
import Foundation
import ImageIO

public struct PaletteGenerator: Sendable {
    private let dateProvider: @Sendable () -> Date
    private struct ColorCandidate {
        var color: RGBColor
        var count: Int
    }

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

        let candidates = rankedCandidates(from: pixels)
        var pywalColors = adjustedPywalColors(
            from: selectedSeedColors(from: candidates, fallback: average),
            light: mode == "light"
        )

        var background = pywalColors[0]
        var foreground = pywalColors[15].adjustedForContrast(
            against: background,
            minimum: config.minimumForegroundContrast
        )
        if foreground.contrastRatio(against: background) < config.minimumForegroundContrast {
            background = mode == "light"
                ? background.mixed(with: .white, amount: 0.15)
                : background.mixed(with: .black, amount: 0.15)
            foreground = foreground.adjustedForContrast(
                against: background,
                minimum: config.minimumForegroundContrast
            )
        }

        pywalColors[0] = background
        pywalColors[7] = pywalColors[7].adjustedForContrast(against: background, minimum: 2.0)
        pywalColors[8] = pywalColors[8].mixed(with: foreground, amount: 0.08)
        pywalColors[15] = foreground

        let accent = dominantAccent(from: candidates, fallback: average)
            .adjustedForContrast(against: background, minimum: config.minimumAccentContrast)

        let selectionSeed = accent.mixed(with: background, amount: mode == "light" ? 0.35 : 0.55)
        let selection = selectionSeed.adjustedForContrast(against: foreground, minimum: 3.0)

        var named = ansiDictionary(from: pywalColors)
        named.merge([
            "background": background,
            "foreground": foreground,
            "cursor": foreground,
            "selection": selection,
            "accent": accent,
            "accentAlt": accent.mixed(with: mode == "light" ? .black : .white, amount: 0.28)
        ]) { _, new in new }

        repairANSIContrast(in: &named, background: background)

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

    private func rankedCandidates(from pixels: [RGBColor]) -> [ColorCandidate] {
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

        return buckets.values
            .map { bucket -> ColorCandidate in
                let color = RGBColor(
                    red: UInt8(bucket.red / bucket.count),
                    green: UInt8(bucket.green / bucket.count),
                    blue: UInt8(bucket.blue / bucket.count)
                )
                return ColorCandidate(color: color, count: bucket.count)
            }
            .sorted { left, right in
                if left.count != right.count {
                    return left.count > right.count
                }
                if left.color.saturation != right.color.saturation {
                    return left.color.saturation > right.color.saturation
                }
                return left.color.hex < right.color.hex
            }
    }

    private func selectedSeedColors(from candidates: [ColorCandidate], fallback: RGBColor) -> [RGBColor] {
        let dominant = Array(candidates.prefix(35)).map(\.color)
        let anchors = dominant.isEmpty ? [fallback] : dominant.sorted { left, right in
            if left.perceivedLuminance == right.perceivedLuminance {
                return left.hex < right.hex
            }
            return left.perceivedLuminance < right.perceivedLuminance
        }

        if anchors.count >= 16 {
            return evenlySample(anchors, count: 16)
        }

        if anchors.count == 1 {
            let color = anchors[0]
            let start = color.mixed(with: .black, amount: 0.45)
            let end = color.mixed(with: .white, amount: 0.62)
            return (0..<16).map { index in
                start.mixed(with: end, amount: Double(index) / 15.0)
            }
        }

        return (0..<16).map { index in
            let position = Double(index) / 15.0 * Double(anchors.count - 1)
            let lower = Int(floor(position))
            let upper = min(anchors.count - 1, lower + 1)
            return anchors[lower].mixed(with: anchors[upper], amount: position - Double(lower))
        }
    }

    private func evenlySample(_ colors: [RGBColor], count: Int) -> [RGBColor] {
        guard count > 1, colors.count > 1 else {
            return Array(colors.prefix(count))
        }

        return (0..<count).map { index in
            let position = Double(index) / Double(count - 1) * Double(colors.count - 1)
            return colors[Int(round(position))]
        }
    }

    private func adjustedPywalColors(from colors: [RGBColor], light: Bool) -> [RGBColor] {
        var raw = [colors[0]]
        raw.append(contentsOf: colors[8..<16])
        raw.append(contentsOf: colors[8..<15])

        if light {
            raw[0] = colors[15].mixed(with: .white, amount: 0.85)
            raw[7] = colors[0]
            raw[8] = colors[15].mixed(with: .black, amount: 0.40)
            raw[15] = colors[0]
        } else {
            if raw[0].red >= 16 {
                raw[0] = raw[0].mixed(with: .black, amount: 0.40)
            }
            let pywalForegroundBlend = RGBColor(red: 238, green: 238, blue: 238)
            raw[7] = raw[7].mixed(with: pywalForegroundBlend, amount: 0.50)
            raw[8] = raw[7].mixed(with: .black, amount: 0.30)
            raw[15] = raw[15].mixed(with: pywalForegroundBlend, amount: 0.50)
        }

        return raw
    }

    private func dominantAccent(from candidates: [ColorCandidate], fallback: RGBColor) -> RGBColor {
        let maxCount = Double(candidates.map(\.count).max() ?? 1)
        let scored = candidates
            .map { candidate -> (Double, RGBColor) in
                let color = candidate.color
                let frequency = Double(candidate.count) / maxCount
                let luminancePenalty = abs(color.perceivedLuminance - 0.52)
                let score = color.saturation * 2.4 + frequency * 0.8 - luminancePenalty * 0.8
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

    private func ansiDictionary(from colors: [RGBColor]) -> [String: RGBColor] {
        [
            "black": colors[0],
            "red": colors[1],
            "green": colors[2],
            "yellow": colors[3],
            "blue": colors[4],
            "magenta": colors[5],
            "cyan": colors[6],
            "white": colors[7],
            "brightBlack": colors[8],
            "brightRed": colors[9],
            "brightGreen": colors[10],
            "brightYellow": colors[11],
            "brightBlue": colors[12],
            "brightMagenta": colors[13],
            "brightCyan": colors[14],
            "brightWhite": colors[15]
        ]
    }

    private func repairANSIContrast(in colors: inout [String: RGBColor], background: RGBColor) {
        for name in ["red", "green", "yellow", "blue", "magenta", "cyan", "white", "brightRed", "brightGreen", "brightYellow", "brightBlue", "brightMagenta", "brightCyan"] {
            colors[name] = colors[name]?.adjustedForContrast(against: background, minimum: 2.0)
        }
        colors["brightWhite"] = colors["brightWhite"]?.adjustedForContrast(against: background, minimum: 7.0)
        colors["foreground"] = colors["foreground"]?.adjustedForContrast(against: background, minimum: 7.0)
        colors["cursor"] = colors["foreground"]
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
