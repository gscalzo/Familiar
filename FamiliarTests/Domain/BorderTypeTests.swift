@testable import FamiliarDomain
import Testing

@Suite("BorderType")
struct BorderTypeTests {
    @Test func noneContainsAllBits() {
        let none = BorderType.none
        #expect(none.contains(.taskbar))
        #expect(none.contains(.window))
        #expect(none.contains(.horizontal))
        #expect(none.contains(.vertical))
    }

    @Test func horizontalPlusIncludesWindowAndHorizontal() {
        let hp = BorderType.horizontalPlus
        #expect(hp.contains(.horizontal))
        #expect(hp.contains(.window))
        #expect(!hp.contains(.taskbar))
        #expect(!hp.contains(.vertical))
    }
}
