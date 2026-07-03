import Foundation

public enum AdapterClassification: String, Codable, Sendable {
    case supported
    case `private`
    case external
    case manual
    case supportedAppConfig = "supported app config"
    case supportedSystemInheritanceOnly = "supported system inheritance only"
    case supportedPrivateMixed = "supported/private mixed"
}

public enum MacwalTarget: String, CaseIterable, Codable, Sendable {
    case system
    case terminal
    case shell
    case obsidian
    case chrome
    case safari
    case spotify
    case finder

    public var classification: AdapterClassification {
        switch self {
        case .shell:
            .supported
        case .terminal:
            .supportedPrivateMixed
        case .obsidian:
            .supportedAppConfig
        case .chrome:
            .manual
        case .safari:
            .supportedSystemInheritanceOnly
        case .spotify:
            .external
        case .system, .finder:
            .private
        }
    }

    public var defaultEnabled: Bool {
        switch self {
        case .shell, .terminal, .obsidian, .chrome:
            true
        case .system, .safari, .spotify, .finder:
            false
        }
    }

    public var requiresAllowPrivate: Bool {
        classification == .private
    }

    public var requiresExternalTool: String? {
        switch self {
        case .spotify:
            "spicetify"
        default:
            nil
        }
    }

    public var note: String {
        switch self {
        case .shell:
            "Writes generated shell, JSON, CSS, and Xresources files."
        case .terminal:
            "Generates Terminal.app profile assets; direct preference mutation is not enabled in the MVP."
        case .obsidian:
            "Writes CSS snippets to configured vaults."
        case .chrome:
            "Generates a Manifest V3 theme folder that must be loaded manually."
        case .safari:
            "No direct browser chrome theming; Safari inherits system appearance."
        case .spotify:
            "Requires Spicetify and writes a Spicetify theme."
        case .system:
            "Private macOS defaults and notifications; opt-in only."
        case .finder:
            "Private Tahoe folder customization; opt-in only."
        }
    }

    public static func parseList(_ rawValue: String, allowPrivate: Bool) throws -> [MacwalTarget] {
        let parts = rawValue.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        if parts.contains("all") {
            return MacwalTarget.allCases.filter { target in
                if target.requiresAllowPrivate && !allowPrivate {
                    return false
                }
                return true
            }
        }

        var result: [MacwalTarget] = []
        for part in parts where !part.isEmpty {
            guard let target = MacwalTarget(rawValue: part) else {
                throw MacwalError.invalidArguments("Unknown target '\(part)'. Run 'macwal list-targets' for valid targets.")
            }
            result.append(target)
        }

        if result.isEmpty {
            throw MacwalError.invalidArguments("At least one target is required.")
        }

        return result
    }
}

public struct TargetInfo: Codable, Equatable, Sendable {
    public let name: String
    public let classification: String
    public let defaultEnabled: Bool
    public let requiresAllowPrivate: Bool
    public let requiresExternalTool: String?
    public let note: String

    public init(target: MacwalTarget) {
        self.name = target.rawValue
        self.classification = target.classification.rawValue
        self.defaultEnabled = target.defaultEnabled
        self.requiresAllowPrivate = target.requiresAllowPrivate
        self.requiresExternalTool = target.requiresExternalTool
        self.note = target.note
    }

    public func jsonValue() -> JSONValue {
        .object([
            "name": .string(name),
            "classification": .string(classification),
            "defaultEnabled": .bool(defaultEnabled),
            "requiresAllowPrivate": .bool(requiresAllowPrivate),
            "requiresExternalTool": requiresExternalTool.map(JSONValue.string) ?? .null,
            "note": .string(note)
        ])
    }
}
