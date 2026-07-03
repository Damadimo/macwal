import Foundation

public struct AdapterPlan: Equatable, Sendable {
    public let target: MacwalTarget
    public let status: String
    public let classification: String
    public let plannedWrites: [String]
    public let messages: [String]

    public init(
        target: MacwalTarget,
        status: String,
        plannedWrites: [String] = [],
        messages: [String] = []
    ) {
        self.target = target
        self.status = status
        self.classification = target.classification.rawValue
        self.plannedWrites = plannedWrites
        self.messages = messages
    }

    public func jsonValue() -> JSONValue {
        .object([
            "target": .string(target.rawValue),
            "status": .string(status),
            "classification": .string(classification),
            "plannedWrites": .array(plannedWrites.map(JSONValue.string)),
            "messages": .array(messages.map(JSONValue.string))
        ])
    }
}

public struct AdapterApplySummary: Equatable, Sendable {
    public let target: MacwalTarget
    public let changedPaths: [String]
    public let messages: [String]

    public init(target: MacwalTarget, changedPaths: [String], messages: [String] = []) {
        self.target = target
        self.changedPaths = changedPaths
        self.messages = messages
    }

    public func jsonValue() -> JSONValue {
        .object([
            "target": .string(target.rawValue),
            "changedPaths": .array(changedPaths.map(JSONValue.string)),
            "messages": .array(messages.map(JSONValue.string))
        ])
    }
}
