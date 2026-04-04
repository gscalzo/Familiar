public struct Expression: Sendable {
    public let raw: String
    public let isDynamic: Bool
    public let isScreenDependent: Bool

    public init(raw: String, isDynamic: Bool, isScreenDependent: Bool) {
        self.raw = raw
        self.isDynamic = isDynamic
        self.isScreenDependent = isScreenDependent
    }

    public func evaluate(context: ExpressionContext) -> Int {
        ExpressionEvaluator.evaluate(raw, context: context)
    }

    public static func constant(_ value: Int) -> Expression {
        Expression(raw: "\(value)", isDynamic: false, isScreenDependent: false)
    }
}
