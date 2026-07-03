import Foundation

public struct RGBColor: Codable, Equatable, Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init(hex: String) throws {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let raw = Int(value, radix: 16) else {
            throw MacwalError.paletteGenerationFailed("Invalid hex color '\(hex)'.")
        }
        self.red = UInt8((raw >> 16) & 0xFF)
        self.green = UInt8((raw >> 8) & 0xFF)
        self.blue = UInt8(raw & 0xFF)
    }

    public var hex: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }

    public var relativeLuminance: Double {
        func component(_ value: UInt8) -> Double {
            let scaled = Double(value) / 255.0
            if scaled <= 0.03928 {
                return scaled / 12.92
            }
            return pow((scaled + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * component(red) + 0.7152 * component(green) + 0.0722 * component(blue)
    }

    public var perceivedLuminance: Double {
        (0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)) / 255.0
    }

    public var saturation: Double {
        let r = Double(red) / 255.0
        let g = Double(green) / 255.0
        let b = Double(blue) / 255.0
        let maxValue = max(r, g, b)
        let minValue = min(r, g, b)
        guard maxValue > 0 else {
            return 0
        }
        return (maxValue - minValue) / maxValue
    }

    public func contrastRatio(against other: RGBColor) -> Double {
        let first = relativeLuminance
        let second = other.relativeLuminance
        let lighter = max(first, second)
        let darker = min(first, second)
        return (lighter + 0.05) / (darker + 0.05)
    }

    public func mixed(with other: RGBColor, amount: Double) -> RGBColor {
        let clamped = max(0, min(1, amount))
        func mix(_ a: UInt8, _ b: UInt8) -> UInt8 {
            UInt8(max(0, min(255, round(Double(a) * (1 - clamped) + Double(b) * clamped))))
        }
        return RGBColor(red: mix(red, other.red), green: mix(green, other.green), blue: mix(blue, other.blue))
    }

    public func adjustedForContrast(against background: RGBColor, minimum: Double) -> RGBColor {
        if contrastRatio(against: background) >= minimum {
            return self
        }

        let target: RGBColor = background.relativeLuminance > 0.5 ? .black : .white
        var best = self
        for step in 1...100 {
            let candidate = mixed(with: target, amount: Double(step) / 100.0)
            best = candidate
            if candidate.contrastRatio(against: background) >= minimum {
                return candidate
            }
        }
        return best
    }

    public static let black = RGBColor(red: 0, green: 0, blue: 0)
    public static let white = RGBColor(red: 255, green: 255, blue: 255)
}
