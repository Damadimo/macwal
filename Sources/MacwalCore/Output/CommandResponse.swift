import Foundation

public struct ResponseMessage: Codable, Equatable, Sendable {
    public let level: String
    public let text: String

    public init(level: String, text: String) {
        self.level = level
        self.text = text
    }
}

public struct CommandResponse: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let command: String
    public let success: Bool
    public let messages: [ResponseMessage]
    public let data: JSONValue?

    public init(
        schemaVersion: Int = 1,
        command: String,
        success: Bool,
        messages: [ResponseMessage] = [],
        data: JSONValue? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.command = command
        self.success = success
        self.messages = messages
        self.data = data
    }

    public func encodedJSON(pretty: Bool = true) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        let data = try encoder.encode(self)
        return String(decoding: data, as: UTF8.self)
    }
}
