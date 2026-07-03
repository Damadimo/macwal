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
}
