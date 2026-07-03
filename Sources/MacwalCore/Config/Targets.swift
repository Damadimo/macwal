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
    case firefox
    case librewolf
    case zen
    case floorp
    case safari
    case spotify
    case alacritty
    case kitty
    case wezterm
    case ghostty
    case iterm2
    case vscode
    case zed
    case vim
    case neovim
    case tmux
    case starship
    case bat
    case btop
    case yazi
    case fzf
    case lazygit
    case aerospace
    case yabai
    case sketchybar
    case jankyBorders = "janky-borders"
    case hammerspoon
    case raycast
    case alfred
    case discord
    case thunderbird
    case telegram
    case slack
    case finder

    public var classification: AdapterClassification {
        switch self {
        case .shell, .alacritty, .kitty, .wezterm, .ghostty, .vim, .neovim, .tmux, .starship, .bat, .btop, .yazi, .fzf, .lazygit, .hammerspoon:
            .supported
        case .terminal:
            .supportedPrivateMixed
        case .obsidian, .firefox, .librewolf, .zen, .floorp, .thunderbird, .iterm2, .vscode, .zed:
            .supportedAppConfig
        case .chrome, .raycast, .alfred, .discord, .telegram, .slack:
            .manual
        case .safari:
            .supportedSystemInheritanceOnly
        case .spotify, .aerospace, .yabai, .sketchybar, .jankyBorders:
            .external
        case .system, .finder:
            .private
        }
    }

    public var defaultEnabled: Bool {
        switch self {
        case .shell, .terminal, .obsidian, .chrome:
            true
        case .system, .firefox, .librewolf, .zen, .floorp, .safari, .spotify, .alacritty, .kitty, .wezterm, .ghostty, .iterm2, .vscode, .zed, .vim, .neovim, .tmux, .starship, .bat, .btop, .yazi, .fzf, .lazygit, .aerospace, .yabai, .sketchybar, .jankyBorders, .hammerspoon, .raycast, .alfred, .discord, .thunderbird, .telegram, .slack, .finder:
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
        case .yabai:
            "yabai"
        case .sketchybar:
            "sketchybar"
        case .jankyBorders:
            "borders"
        case .aerospace:
            "aerospace"
        default:
            nil
        }
    }

    public var note: String {
        switch self {
        case .shell:
            "Writes generated shell, JSON, CSS, and Xresources files."
        case .terminal:
            "Generates and installs a Terminal.app profile as the default profile."
        case .obsidian:
            "Writes CSS snippets to configured vaults."
        case .chrome:
            "Generates a Manifest V3 theme folder; Chrome has no supported per-user silent activation API."
        case .firefox:
            "Writes Firefox profile userChrome/userContent CSS and user.js preferences; Firefox restart required."
        case .librewolf:
            "Writes LibreWolf profile CSS and user.js preferences; restart required."
        case .zen:
            "Writes Zen Browser profile CSS and user.js preferences; restart required."
        case .floorp:
            "Writes Floorp profile CSS and user.js preferences; restart required."
        case .safari:
            "No direct browser chrome theming; Safari inherits system appearance."
        case .spotify:
            "Requires Spicetify and writes a Spicetify theme."
        case .alacritty:
            "Writes Alacritty TOML colors and attempts to add an import."
        case .kitty:
            "Writes Kitty color config, includes it from kitty.conf, and attempts live reload."
        case .wezterm:
            "Writes a WezTerm Lua color scheme."
        case .ghostty:
            "Writes a Ghostty theme file and selects it from config."
        case .iterm2:
            "Writes an iTerm2 Dynamic Profile color scheme."
        case .vscode:
            "Writes a VS Code theme extension and selects it when settings.json is valid JSON."
        case .zed:
            "Writes a Zed theme JSON file."
        case .vim:
            "Writes a Vim colorscheme and enables it from .vimrc."
        case .neovim:
            "Writes a Neovim colorscheme and enables it from init.vim or init.lua."
        case .tmux:
            "Writes a tmux theme file, sources it from tmux.conf, and attempts reload."
        case .starship:
            "Writes a Starship palette fragment."
        case .bat:
            "Writes a bat theme and configures bat to use it."
        case .btop:
            "Writes a btop theme and configures btop to use it."
        case .yazi:
            "Writes a Yazi theme file."
        case .fzf:
            "Writes fzf color exports and sources them from common shell rc files."
        case .lazygit:
            "Writes a Lazygit theme config when no existing config would be overwritten."
        case .aerospace:
            "Writes an AeroSpace color fragment for user config integration."
        case .yabai:
            "Runs yabai border-color commands when yabai is available."
        case .sketchybar:
            "Runs sketchybar color commands when sketchybar is available."
        case .jankyBorders:
            "Runs janky borders color commands when borders is available."
        case .hammerspoon:
            "Writes Hammerspoon Lua colors and loads them from init.lua."
        case .raycast:
            "Generates Raycast palette assets only; Raycast theme activation is not file-configurable."
        case .alfred:
            "Generates Alfred palette assets only; automatic activation is not implemented."
        case .discord:
            "Writes Vencord/BetterDiscord CSS theme files when theme folders exist."
        case .thunderbird:
            "Writes Thunderbird profile userChrome CSS and user.js preferences; restart required."
        case .telegram:
            "Generates Telegram Desktop theme assets only; activation remains manual."
        case .slack:
            "Generates Slack palette assets only; Slack does not expose stable theme dotfiles."
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
