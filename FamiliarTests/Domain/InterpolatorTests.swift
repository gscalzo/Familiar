@testable import FamiliarDomain
import Testing

@Suite("Interpolator")
struct InterpolatorTests {
    @Test func valueAtStart() {
        #expect(Interpolator.value(start: 10, end: 50, step: 0, totalSteps: 4) == 10)
    }

    @Test func valueAtEnd() {
        #expect(Interpolator.value(start: 10, end: 50, step: 4, totalSteps: 4) == 50)
    }

    @Test func valueMidpoint() {
        #expect(Interpolator.value(start: 0, end: 100, step: 2, totalSteps: 4) == 50)
    }

    @Test func valueZeroSteps() {
        #expect(Interpolator.value(start: 10, end: 50, step: 0, totalSteps: 0) == 10)
    }

    @Test func valueNegativeRange() {
        #expect(Interpolator.value(start: 100, end: 0, step: 2, totalSteps: 4) == 50)
    }

    @Test func movementAtStart() {
        #expect(Interpolator.movement(start: 0, end: 30, step: 0, totalSteps: 4) == 0)
    }

    @Test func movementAtEnd() {
        // Uses totalSteps-1 as denominator: 0 + 30 * 3 / 3 = 30
        #expect(Interpolator.movement(start: 0, end: 30, step: 3, totalSteps: 4) == 30)
    }

    @Test func movementSingleStep() {
        #expect(Interpolator.movement(start: 5, end: 20, step: 0, totalSteps: 1) == 5)
    }

    @Test func movementMidpoint() {
        // 0 + 60 * 1 / 3 = 20
        #expect(Interpolator.movement(start: 0, end: 60, step: 1, totalSteps: 4) == 20)
    }
}
