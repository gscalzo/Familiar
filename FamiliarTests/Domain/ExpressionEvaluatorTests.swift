@testable import FamiliarDomain
import Testing

@Suite("ExpressionEvaluator")
struct ExpressionEvaluatorTests {
    let ctx = ExpressionContext(
        screenW: 1920, screenH: 1080,
        areaW: 1920, areaH: 1055,
        imageW: 64, imageH: 64,
        imageX: 100, imageY: 200,
        random: 42, randS: 50, scale: 2
    )

    @Test func integerLiteral() {
        #expect(ExpressionEvaluator.evaluate("100", context: ctx) == 100)
    }

    @Test func negativeLiteral() {
        #expect(ExpressionEvaluator.evaluate("-5", context: ctx) == -5)
    }

    @Test func addition() {
        #expect(ExpressionEvaluator.evaluate("10+20", context: ctx) == 30)
    }

    @Test func subtraction() {
        #expect(ExpressionEvaluator.evaluate("50-30", context: ctx) == 20)
    }

    @Test func multiplication() {
        #expect(ExpressionEvaluator.evaluate("6*7", context: ctx) == 42)
    }

    @Test func division() {
        #expect(ExpressionEvaluator.evaluate("100/3", context: ctx) == 33)
    }

    @Test func divisionByZero() {
        #expect(ExpressionEvaluator.evaluate("10/0", context: ctx) == 0)
    }

    @Test func operatorPrecedence() {
        #expect(ExpressionEvaluator.evaluate("2+3*4", context: ctx) == 14)
    }

    @Test func parentheses() {
        #expect(ExpressionEvaluator.evaluate("(2+3)*4", context: ctx) == 20)
    }

    @Test func variableScreenW() {
        #expect(ExpressionEvaluator.evaluate("screenW", context: ctx) == 1920)
    }

    @Test func variableAreaH() {
        #expect(ExpressionEvaluator.evaluate("areaH", context: ctx) == 1055)
    }

    @Test func variableRandom() {
        #expect(ExpressionEvaluator.evaluate("random", context: ctx) == 42)
    }

    @Test func variableImageW() {
        #expect(ExpressionEvaluator.evaluate("imageW", context: ctx) == 64)
    }

    @Test func variableScale() {
        #expect(ExpressionEvaluator.evaluate("scale", context: ctx) == 2)
    }

    @Test func complexExpression() {
        // screenW - imageW * 2 = 1920 - 128 = 1792
        #expect(ExpressionEvaluator.evaluate("screenW-imageW*2", context: ctx) == 1792)
    }

    @Test func expressionWithSpaces() {
        #expect(ExpressionEvaluator.evaluate(" 10 + 20 ", context: ctx) == 30)
    }

    @Test func nestedParentheses() {
        #expect(ExpressionEvaluator.evaluate("((2+3))*4", context: ctx) == 20)
    }

    @Test func emptyStringReturnsZero() {
        #expect(ExpressionEvaluator.evaluate("", context: ctx) == 0)
    }

    @Test func unknownVariableReturnsZero() {
        #expect(ExpressionEvaluator.evaluate("foobar", context: ctx) == 0)
    }
}
