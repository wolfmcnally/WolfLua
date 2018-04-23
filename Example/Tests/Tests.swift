import XCTest
@testable import WolfLua

class Tests: XCTestCase {
    func test1() {
        let lua = Lua()
        XCTAssertEqual(lua.stackDescription, "empty")

        lua.pushNumber(5.5)
        XCTAssertEqual(lua.stackDescription, "[5.5]")

        lua.pushBoolean(true)
        XCTAssertEqual(lua.stackDescription, "[5.5] [true]")

        lua.pushString("Hello")
        XCTAssertEqual(lua.stackDescription, "[5.5] [true] ['Hello']")

        lua.pop(2)
        XCTAssertEqual(lua.stackDescription, "[5.5]")

        lua.pushInteger(3)
        XCTAssertEqual(lua.stackDescription, "[5.5] [3]")
        XCTAssertNoThrow(try lua.arith(op: .add))
        XCTAssertEqual(lua.stackDescription, "[8.5]")

        XCTAssertNoThrow(try lua.newThread())
        XCTAssertEqual(lua.stackDescription, "[8.5] [Thread]")

        lua.rotate(at: -2, count: 1)
        XCTAssertEqual(lua.stackDescription, "[Thread] [8.5]")
        lua.pushInteger(30)
        XCTAssertEqual(lua.stackDescription, "[Thread] [8.5] [30]")
        XCTAssertNoThrow(try lua.isComparable(stackIndex1: -2, stackIndex2: -1, by: .lessThan) == true)
        XCTAssertEqual(lua.stackDescription, "[Thread] [8.5] [30]")
        XCTAssertNoThrow(try lua.isComparable(stackIndex1: -1, stackIndex2: -2, by: .lessThan) == false)
        XCTAssertEqual(lua.stackDescription, "[Thread] [8.5] [30]")

        XCTAssertNoThrow(try lua.setGlobal(name: "a"))
        XCTAssertEqual(lua.stackDescription, "[Thread] [8.5]")
        XCTAssertNoThrow(try lua.setGlobal(name: "b"))
        XCTAssertEqual(lua.stackDescription, "[Thread]")
        XCTAssertNoThrow(try lua.getGlobal(named: "a"))
        XCTAssertEqual(lua.stackDescription, "[Thread] [30]")
        XCTAssertNoThrow(try lua.getGlobal(named: "b"))
        XCTAssertEqual(lua.stackDescription, "[Thread] [30] [8.5]")

        lua.pop(3)
        XCTAssertEqual(lua.stackDescription, "empty")
    }

    func test2() {
        let lua = Lua()
        lua.newTable()
        XCTAssertEqual(lua.stackDescription, "[Table]")

        lua.pushString("animal")
        lua.pushString("giraffe")
        XCTAssertEqual(lua.stackDescription, "[Table] ['animal'] ['giraffe']")
        XCTAssertNoThrow(try lua.setInTable(at: -3))
        XCTAssertEqual(lua.stackDescription, "[Table]")

        lua.pushString("green")
        XCTAssertEqual(lua.stackDescription, "[Table] ['green']")
        XCTAssertNoThrow(try lua.setFieldInTable(at: -3, named: "color"))
        XCTAssertEqual(lua.stackDescription, "[Table]")

        lua.pushString("twelfth")
        XCTAssertEqual(lua.stackDescription, "[Table] ['twelfth']")
        XCTAssertNoThrow(try lua.setIndexInTable(at: -3, index: 12))

        lua.pushString("animal")
        XCTAssertEqual(lua.stackDescription, "[Table] ['animal']")
        XCTAssertNoThrow(try lua.getInTable(at: -2))
        XCTAssertEqual(lua.stackDescription, "[Table] ['giraffe']")

        XCTAssertNoThrow(try lua.getFieldInTable(at: -2, named: "color"))
        XCTAssertEqual(lua.stackDescription, "[Table] ['giraffe'] ['green']")

        XCTAssertNoThrow(try lua.getIndexInTable(at: -3, for: 12))
        XCTAssertEqual(lua.stackDescription, "[Table] ['giraffe'] ['green'] ['twelfth']")
    }
}
