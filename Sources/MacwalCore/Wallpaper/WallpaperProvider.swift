import AppKit
import Foundation

public struct WallpaperRecord: Equatable, Sendable {
    public let index: Int
    public let displayID: UInt32?
    public let url: URL

    public init(index: Int, displayID: UInt32?, url: URL) {
        self.index = index
        self.displayID = displayID
        self.url = url
    }
}

@MainActor
public protocol WallpaperProviding {
    func wallpapers() throws -> [WallpaperRecord]
    /// Set the desktop wallpaper on every attached display to `url`.
    func setWallpaper(_ url: URL) throws
}

public struct AppKitWallpaperProvider: WallpaperProviding {
    public init() {}

    public func wallpapers() throws -> [WallpaperRecord] {
        let workspace = NSWorkspace.shared
        return NSScreen.screens.enumerated().compactMap { index, screen in
            guard let url = workspace.desktopImageURL(for: screen) else {
                return nil
            }

            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
            return WallpaperRecord(index: index, displayID: displayID, url: url)
        }
    }

    public func setWallpaper(_ url: URL) throws {
        let workspace = NSWorkspace.shared
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            throw MacwalError.adapterFailed("No displays are attached; cannot set the desktop wallpaper.")
        }
        // Preserve each display's existing scaling/fill options so setting the
        // image does not reset the user's fit-to-screen preference.
        for screen in screens {
            let options = workspace.desktopImageOptions(for: screen) ?? [:]
            try workspace.setDesktopImageURL(url, for: screen, options: options)
        }
    }
}
