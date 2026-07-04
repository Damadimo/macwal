import Foundation

/// Quits and relaunches GUI applications whose theme or config is only read at
/// launch, so a freshly written theme takes effect without any manual step.
///
/// This implements the "Always auto-restart" behavior selected for targets that
/// expose no live-reload API (browsers, Terminal.app, Ghostty, Thunderbird, …).
/// Loss of transient state (open tabs, unsaved work) is accepted by design.
///
/// Set `MACWAL_SKIP_RESTART` in the environment to make every restart a no-op —
/// tests and smoke runs use this so they never touch real running apps.
public struct AppRestarter {
    public let commandExecutor: CommandExecutor

    public init(commandExecutor: CommandExecutor) {
        self.commandExecutor = commandExecutor
    }

    /// Restart an application.
    ///
    /// - Parameters:
    ///   - appName: Name of the `.app` used to relaunch (`open -a`) and in
    ///     messages (e.g. "Terminal", "LibreWolf").
    ///   - processName: Executable name for `pgrep`/`killall` (e.g. "firefox").
    ///   - selfTermProgram: If the current `$TERM_PROGRAM` equals this value the
    ///     app is hosting the macwal process itself; quitting it would kill this
    ///     run, so the restart is skipped and the caller is told to do it by hand.
    /// - Returns: A human-readable status line describing what happened.
    public func restart(
        appName: String,
        processName: String,
        selfTermProgram: String? = nil
    ) -> String {
        if commandExecutor.environment["MACWAL_SKIP_RESTART"] != nil {
            return "\(appName) restart skipped (MACWAL_SKIP_RESTART set)."
        }

        guard isRunning(processName: processName) else {
            return "\(appName) is not running; the new theme will load the next time it opens."
        }

        if let selfTermProgram, commandExecutor.environment["TERM_PROGRAM"] == selfTermProgram {
            return "\(appName) is hosting this command; quit and reopen \(appName) yourself to load the new theme."
        }

        // Graceful terminate (SIGTERM), give it a moment to exit cleanly, then
        // force it if it is still alive.
        _ = try? commandExecutor.run(executable: "/usr/bin/killall", arguments: [processName])
        if !waitForExit(processName: processName, timeout: 5.0) {
            _ = try? commandExecutor.run(executable: "/usr/bin/killall", arguments: ["-9", processName])
            _ = waitForExit(processName: processName, timeout: 3.0)
        }

        let relaunch = try? commandExecutor.run(executable: "/usr/bin/open", arguments: ["-a", appName])
        if let relaunch, relaunch.exitCode == 0 {
            return "Restarted \(appName) to load the new theme."
        }
        return "Quit \(appName); could not relaunch it automatically — reopen it to load the new theme."
    }

    /// Send a signal to every process matching `processName` (used by apps that
    /// reload their config on a signal, e.g. kitty on SIGUSR1). No-op — and
    /// honestly reported — when the app is not running or restarts are skipped.
    public func signal(_ signalName: String, processName: String, appName: String) -> String {
        if commandExecutor.environment["MACWAL_SKIP_RESTART"] != nil {
            return "\(appName) reload skipped (MACWAL_SKIP_RESTART set)."
        }
        guard isRunning(processName: processName) else {
            return "\(appName) is not running; the new theme will load the next time it opens."
        }
        let result = try? commandExecutor.run(executable: "/usr/bin/killall", arguments: ["-\(signalName)", processName])
        if let result, result.exitCode == 0 {
            return "Signalled \(appName) (\(signalName)) to reload the new theme."
        }
        return "Could not signal \(appName) to reload; restart it to load the new theme."
    }

    public func isRunning(processName: String) -> Bool {
        guard let result = try? commandExecutor.run(executable: "/usr/bin/pgrep", arguments: ["-x", processName]) else {
            return false
        }
        return result.exitCode == 0
    }

    private func waitForExit(processName: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !isRunning(processName: processName) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return !isRunning(processName: processName)
    }
}
