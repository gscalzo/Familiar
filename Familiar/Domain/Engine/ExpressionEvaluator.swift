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
        while true {
            skipWhitespace()
            guard let ch = peek() else { break }
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
        while true {
            skipWhitespace()
            guard let ch = peek() else { break }
            if ch == "*" {
                pos += 1
                result *= parseFactor()
            } else if ch == "/" {
                pos += 1
                let divisor = parseFactor()
                result = divisor == 0 ? 0 : result / divisor
            } else {
                break
            }
        }
        return result
    }

    private mutating func parseFactor() -> Int {
        skipWhitespace()
        guard let ch = peek() else { return 0 }

        if ch == "-" {
            pos += 1
            return -parseFactor()
        }

        if ch == "(" {
            pos += 1
            let result = parseExpr()
            skipWhitespace()
            if peek() == ")" { pos += 1 }
            return result
        }

        if ch.isNumber {
            return parseNumber()
        }

        if ch.isLetter {
            return lookupVariable(parseIdentifier())
        }

        return 0
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

    // swiftlint:disable:next cyclomatic_complexity
    private func lookupVariable(_ name: String) -> Int {
        switch name {
        case "screenW": context.screenW
        case "screenH": context.screenH
        case "areaW": context.areaW
        case "areaH": context.areaH
        case "imageW": context.imageW
        case "imageH": context.imageH
        case "imageX": context.imageX
        case "imageY": context.imageY
        case "random": context.random
        case "randS": context.randS
        case "scale": context.scale
        default: 0
        }
    }
}
