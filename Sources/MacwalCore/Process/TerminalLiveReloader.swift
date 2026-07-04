import Foundation

/// Builds the ANSI OSC escape sequences that recolor a terminal in place.
///
/// A theme is just colors, and every modern terminal (including Apple Terminal
/// and Ghostty) lets you change them at runtime with OSC sequences: `10` is the
/// foreground, `11` the background, `12` the cursor, and `4;N` each of the 16
/// ANSI palette entries. Writing these to an open window's TTY recolors it
/// instantly — no relaunch, no lost sessions.
public enum TerminalColorSequence {
    /// The 16 ANSI palette entries in index order (0…15) mapped to palette keys.
    static let ansiKeys = [
        "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
        "brightBlack", "brightRed", "brightGreen", "brightYellow", "brightBlue",
        "brightMagenta", "brightCyan", "brightWhite"
    ]

    /// Concatenated OSC sequences for the given palette, or nil when the palette
    /// is missing the foreground/background it needs. Each sequence is
    /// `ESC ] <code> ; <#RRGGBB> BEL`.
    public static func sequences(for palette: PaletteDocument) -> String? {
        guard let foreground = palette.colors["foreground"],
              let background = palette.colors["background"] else {
            return nil
        }

        let esc = "\u{1B}"
        let bel = "\u{07}"
        var out = ""
        out += "\(esc)]10;\(foreground)\(bel)"
        out += "\(esc)]11;\(background)\(bel)"
        if let cursor = palette.colors["cursor"] {
            out += "\(esc)]12;\(cursor)\(bel)"
        }
        for (index, key) in ansiKeys.enumerated() {
            guard let hex = palette.colors[key] else { continue }
            out += "\(esc)]4;\(index);\(hex)\(bel)"
        }
        return out
    }
}

/// Recolors every open window of a terminal in place by writing OSC color
/// sequences to each window's TTY, instead of quitting and relaunching the app.
///
/// Windows are found by asking `ps` for processes whose `$TERM_PROGRAM` matches
/// the terminal (e.g. `Apple_Terminal`, `ghostty`) and collecting their
/// controlling TTYs. Only colors change live; window properties such as opacity
/// come from the profile/config and take effect in windows opened afterwards.
///
/// Honors `MACWAL_SKIP_RESTART` exactly like ``AppRestarter`` so tests and smoke
/// runs never write to a real TTY.
public struct TerminalLiveReloader {
    public let commandExecutor: CommandExecutor

    public init(commandExecutor: CommandExecutor) {
        self.commandExecutor = commandExecutor
    }

    /// - Parameters:
    ///   - termProgram: The value the terminal sets in `$TERM_PROGRAM`
    ///     (`Apple_Terminal`, `ghostty`, …); used to find its windows.
    ///   - appName: Human-readable name for status messages.
    ///   - sequences: The OSC bytes to write (see ``TerminalColorSequence``).
    /// - Returns: A human-readable status line describing what happened.
    public func reload(termProgram: String, appName: String, sequences: String) -> String {
        if commandExecutor.environment["MACWAL_SKIP_RESTART"] != nil {
            return "\(appName) live recolor skipped (MACWAL_SKIP_RESTART set)."
        }

        let ttys = openTTYs(forTermProgram: termProgram)
        guard !ttys.isEmpty else {
            return "\(appName) has no open windows to recolor; new windows will use the theme."
        }

        var recolored = 0
        for tty in ttys where writeSequences(sequences, toTTY: tty) {
            recolored += 1
        }

        if recolored == 0 {
            return "\(appName) is open but its windows could not be recolored; new windows will use the theme."
        }
        let plural = recolored == 1 ? "" : "s"
        return "Recolored \(recolored) open \(appName) window\(plural) in place (no restart)."
    }

    /// TTY device names (e.g. `ttys001`) of processes whose environment contains
    /// `TERM_PROGRAM=<termProgram>`.
    func openTTYs(forTermProgram termProgram: String) -> [String] {
        // `-E` appends each process's environment, so we can match TERM_PROGRAM
        // and read its controlling TTY from the first (`tty=`) column.
        guard let result = try? commandExecutor.run(
            executable: "/bin/ps",
            arguments: ["-A", "-E", "-o", "tty=,command="]
        ), let text = String(data: result.stdout, encoding: .utf8) else {
            return []
        }
        return Self.parseTTYs(psOutput: text, termProgram: termProgram)
    }

    /// Pure parser: given `ps` output where each line begins with a TTY column,
    /// return the unique TTYs of lines whose environment names `termProgram`.
    /// Lines with no controlling terminal (`??`) are ignored.
    public static func parseTTYs(psOutput: String, termProgram: String) -> [String] {
        let needle = "TERM_PROGRAM=\(termProgram)"
        var seen = Set<String>()
        var ttys: [String] = []
        for rawLine in psOutput.split(separator: "\n") {
            guard rawLine.contains(needle) else { continue }
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let field = line.split(separator: " ", omittingEmptySubsequences: true).first else { continue }
            let tty = String(field)
            guard tty != "??", tty.hasPrefix("tty") else { continue }
            if seen.insert(tty).inserted {
                ttys.append(tty)
            }
        }
        return ttys
    }

    /// Write the sequence bytes to `/dev/<tty>`. Returns false (and does nothing
    /// harmful) if the device cannot be opened or written.
    private func writeSequences(_ sequences: String, toTTY tty: String) -> Bool {
        guard let data = sequences.data(using: .utf8),
              let handle = FileHandle(forWritingAtPath: "/dev/\(tty)") else {
            return false
        }
        defer { try? handle.close() }
        do {
            try handle.write(contentsOf: data)
            return true
        } catch {
            return false
        }
    }
}
