import Foundation

public enum MacwalError: Error, Equatable {
    case invalidArguments(String)
    case missingPrerequisite(String)
    case permissionDenied(String)
    case adapterFailed(String)
    case paletteGenerationFailed(String)
    case restoreFailed(String)
}

extension MacwalError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidArguments(let message),
             .missingPrerequisite(let message),
             .permissionDenied(let message),
             .adapterFailed(let message),
             .paletteGenerationFailed(let message),
             .restoreFailed(let message):
            message
        }
    }

    public var exitCode: Int32 {
        switch self {
        case .invalidArguments:
            1
        case .missingPrerequisite:
            2
        case .permissionDenied:
            3
        case .adapterFailed:
            4
        case .paletteGenerationFailed:
            5
        case .restoreFailed:
            6
        }
    }
}
