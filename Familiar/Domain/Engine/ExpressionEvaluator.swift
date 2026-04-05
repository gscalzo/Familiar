public enum ExpressionEvaluator {
    public static func evaluate(_ raw: String, context: ExpressionContext) -> Int {
        var parser = Parser(raw, context: context)
        return parser.parseExpr()
    }
}

private struct Parser {
    private let chars: [Character]
    private let context: ExpressionContext
    private var pos: Int = 0

    init(_ input: String, context: ExpressionContext) {
        self.chars = Array(input)
        self.context = context
    }

    private mutating func skipWhitespace() {
        while pos < chars.count, chars[pos].isWhitespace {
            pos += 1
        }
    }

    private func peek() -> Character? {
        pos < chars.count ? chars[pos] : nil
    }

    mutating func parseExpr() -> Int {
        skipWhitespace()
        guard pos < chars.count else { return 0 }
        var result = parseTerm()
        result = parseAdditiveOps(result)
        return result
    }

    private mutating func parseAdditiveOps(_ initial: Int) -> Int {
        var result = initial
        while let ch = peekAfterWhitespace() {
            if ch == "+" {
                pos += 1
                result += parseTerm()
            } else if ch == "-" {
                pos += 1
                result -= parseTerm()
            } else {
                break
            }
        }
        return result
    }

    private mutating func parseTerm() -> Int {
        var result = parseFactor()
        result = parseMultiplicativeOps(result)
        return result
    }

    private mutating func parseMultiplicativeOps(_ initial: Int) -> Int {
        var result = initial
        while let ch = peekAfterWhitespace() {
            if ch == "*" {
                pos += 1
                result *= parseFactor()
            } else if ch == "/" {
                pos += 1
                result = safeDivide(result, by: parseFactor())
            } else {
                break
            }
        }
        return result
    }

    private func safeDivide(_ dividend: Int, by divisor: Int) -> Int {
        divisor == 0 ? 0 : dividend / divisor
    }

    private mutating func peekAfterWhitespace() -> Character? {
        skipWhitespace()
        return peek()
    }

    private mutating func parseFactor() -> Int {
        skipWhitespace()
        guard let ch = peek() else { return 0 }

        if ch == "-" { return parseNegation() }
        if ch == "(" { return parseParenthesized() }
        return parseAtomOrZero(ch)
    }

    private mutating func parseAtomOrZero(_ ch: Character) -> Int {
        if ch.isNumber { return parseNumber() }
        if ch.isLetter { return lookupVariable(parseIdentifier()) }
        return 0
    }

    private mutating func parseNegation() -> Int {
        pos += 1
        return -parseFactor()
    }

    private mutating func parseParenthesized() -> Int {
        pos += 1
        let result = parseExpr()
        skipWhitespace()
        if peek() == ")" { pos += 1 }
        return result
    }

    private mutating func parseNumber() -> Int {
        var value = 0
        while let ch = peek(), ch.isNumber {
            value = value * 10 + (ch.wholeNumberValue ?? 0)
            pos += 1
        }
        return value
    }

    private mutating func parseIdentifier() -> String {
        var name = ""
        while let ch = peek(), ch.isLetter || ch.isNumber {
            name.append(ch)
            pos += 1
        }
        return name
    }

    private nonisolated(unsafe) static let variableLookup: [String: (ExpressionContext) -> Int] = [
        "screenW": \.screenW,
        "screenH": \.screenH,
        "areaW": \.areaW,
        "areaH": \.areaH,
        "imageW": \.imageW,
        "imageH": \.imageH,
        "imageX": \.imageX,
        "imageY": \.imageY,
        "random": \.random,
        "randS": \.randS,
        "scale": \.scale,
    ]

    private func lookupVariable(_ name: String) -> Int {
        Self.variableLookup[name]?(context) ?? 0
    }
}
