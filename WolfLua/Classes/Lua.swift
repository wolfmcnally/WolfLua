import Foundation
import CLua

public func helloLua() {
    let luaHelloWorld = """
    print("Hello, world!")
    """

    do {
        let lua = Lua()
        try lua.run(luaHelloWorld)
    } catch {
        print(error.localizedDescription)
    }
}

public class Lua {
    private let luaState: LuaState
    private let isStateOwner: Bool

    public init() {
        luaState = luaL_newstate()
        luaL_openlibs(luaState)
        isStateOwner = true
    }

    private init(luaState: LuaState) {
        self.luaState = luaState
        isStateOwner = false
    }

    deinit {
        guard isStateOwner else { return }
        lua_close(luaState)
    }

    private func loadString(_ s: String) {
        luaL_loadstring(luaState, s)
    }

    public func run(_ s: String) throws {
        loadString(s)
        try pcall(argumentsCount: 1, resultsCount: 1)
    }

    private func checkStatus(_ status: LuaInt) throws {
        guard status != LuaStatus.ok.rawValue else { return }
        let message = try! toString()! // error within an error-- crash
        throw LuaError(status: LuaStatus(rawValue: status)!, message: message)
    }

    // Each function has an indicator like this: `[-o, +p, x]`

    // The first field, `o`, is how many elements the function pops from the stack.
    // The second field, `p`, is how many elements the function pushes onto the stack. (Any function always pushes its results after popping its arguments.) A field in the form `x|y` means the function can push (or pop) `x` or `y` elements, depending on the situation; an interrogation mark '?' means that we cannot know how many elements the function pops/pushes by looking only at its arguments (e.g., they may depend on what is on the stack).
    // The third field, `x`, tells whether the function may raise errors:
    //   '-' means the function never raises any error;
    //   'm' means the function may raise out-of-memory errors and errors running a __gc metamethod;
    //   'e' means the function may raise any errors (it can run arbitrary Lua code, either directly or through metamethods);
    //   'v' means the function may raise an error on purpose.
    //   'throws' as with 'e' means the function may raise errors, but which in turn throw a Swift exception.

    //---------------------------------------------------------
    // MARK: - Versioning
    //---------------------------------------------------------

    /// Returns the version number of the version used to create the current state.
    /// [-0, +0, –]
    public var version: Double {
        return lua_version(luaState).pointee
    }

    /// Returns the address of the version running the call.
    /// [-0, +0, –]
    public static var version: Double {
        return lua_version(nil).pointee
    }

    /// Returns the name of the type encoded by the value `type`.
    /// [-0, +0, –]
    public func typeName(for type: LuaType) -> String {
        return String(luaString: lua_typename(luaState, type.rawValue))
    }

    //---------------------------------------------------------
    // MARK: - State manipulation
    //---------------------------------------------------------

    /// Creates a new thread, pushes it on the stack, and returns a pointer to a `Lua` instance that represents this new thread. The new thread returned by this function shares with the original thread its global environment, but has an independent execution stack.
    /// There is no explicit function to close or to destroy a thread. Threads are subject to garbage collection, like any Lua object.
    /// [-0, +1, m]
    public func newThread() throws -> Lua {
        pushCFunction { luaState in
            lua_newthread(luaState)
            return 1
        }
        try pcall(argumentsCount: 0, resultsCount: 1)
        return toThread()!
    }

    //---------------------------------------------------------
    // MARK: - Basic stack manipulation
    //---------------------------------------------------------

    /// Converts the acceptable `index` into an equivalent absolute index (that is, one that does not depend on the stack top).
    /// [-0, +0, -]
    public func absIndex(of stackIndex: LuaInt = -1) -> LuaInt {
        return lua_absindex(luaState, stackIndex)
    }

    /// The getter of this attribute returns the index of the top element in the stack. Because indices start at 1, this result is equal to the number of elements in the stack; in particular, 0 means an empty stack.
    /// The setter of this attribute accepts any index, or 0, and sets the stack top to this index. If the new top is larger than the old one, then the new elements are filled with nil. If index is 0, then all stack elements are removed.
    /// get: [-0, +0, -], set: [-?, +?, -]
    public var topIndex: LuaInt {
        get { return lua_gettop(luaState) }
        set { lua_settop(luaState, newValue) }
    }

    public var count: LuaInt { return topIndex }
    public var isEmpty: Bool { return count == 0 }

    /// Pushes a copy of the element at the given valid index onto the stack.
    /// [-0, +1, -]
    public func pushValue(at stackIndex: LuaInt = -1) {
        lua_pushvalue(luaState, stackIndex)
    }

    public func dup(at stackIndex: LuaInt = -1) {
        lua_pushvalue(luaState, stackIndex)
    }

    /// Rotates the stack elements between the valid `index` and the top of the stack. The elements are rotated `count` positions in the direction of the top, for a positive `count`, or `-count` positions in the direction of the bottom, for a negative `count`. The absolute value of `count` must not be greater than the size of the slice being rotated. This function cannot be called with a pseudo-index, because a pseudo-index is not an actual stack position.
    /// [-0, +0, -]
    public func rotate(at stackIndex: LuaInt, count: LuaInt) {
        lua_rotate(luaState, stackIndex, count)
    }

    /// Swaps the stack element at `stackIndex` with the element that precedes it. By default, swaps the top two stack elements.
    /// [-0, +0, -]
    func swap(at stackIndex: LuaInt = -1) {
        rotate(at: stackIndex - 1, count: 1)
    }

    /// Copies the element at index fromidx into the valid index toidx, replacing the value at that position. Values at other positions are not affected.
    /// [-0, +0, -]
    public func copy(from fromStackIndex: LuaInt, to toStackIndex: LuaInt) {
        lua_copy(luaState, fromStackIndex, toStackIndex)
    }

    /// Ensures that the stack has space for at least `minAvailableSlots` extra slots (that is, that you can safely push up to `minAvailableSlots` values into it). It returns `false` if it cannot fulfill the request, either because it would cause the stack to be larger than a fixed maximum size (typically at least several thousand elements) or because it cannot allocate memory for the extra space. This function never shrinks the stack; if the stack already has space for the extra slots, it is left unchanged.
    /// [-0, +0, -]
    public func checkStack(for minAvailableSlots: LuaInt) -> Bool {
        return lua_checkstack(luaState, minAvailableSlots) != 0 ? true : false
    }

    /// Pops `count` elements from the stack.
    /// [-count, +0, -]
    func pop(_ count: LuaInt = 1) {
        lua_settop(luaState, -count - 1)
    }

    /// Moves the top element into the given valid index, shifting up the elements above this index to open space. This function cannot be called with a pseudo-index, because a pseudo-index is not an actual stack position.
    /// [-1, +1, –]
    func insert(at stackIndex: LuaInt) {
        rotate(at: stackIndex, count: 1)
    }

    /// Removes the element at the given valid index, shifting down the elements above this index to fill the gap. Cannot be called with a pseudo-index, because a pseudo-index is not an actual stack position.
    /// [-1, +0, -]
    func remove(at stackIndex: LuaInt) {
        rotate(at: stackIndex, count: -1)
        pop()
    }

    /// Moves the top element into the given position (and pops it), without shifting any element (therefore replacing the value at the given position).
    /// [-1, +0, -]
    func replace(at stackIndex: LuaInt) {
        rotate(at: -1, count: stackIndex)
        pop()
    }

    /// Exchange values between different threads of the same state.
    /// This function pops `count` values from this state's stack, and pushes them onto the stack of state `toLua`.
    /// from: [-count, +0, -], to: [-0, +count, -]
    public func xMove(to toLua: Lua, count: LuaInt) {
        lua_xmove(luaState, toLua.luaState, count)
    }

    //---------------------------------------------------------
    // MARK: - Access functions (stack -> Swift)
    //---------------------------------------------------------

    /// Returns `true` if the value at the given index is a number or a string convertible to a number, and `false` otherwise.
    /// [-0, +0, -]
    public func isNumber(at stackIndex: LuaInt = -1) -> Bool {
        return lua_isnumber(luaState, stackIndex) != 0 ? true : false
    }

    /// Returns `true` if the value at the given index is a string or a number (which is always convertible to a string), and `false` otherwise.
    /// [-0, +0, -]
    public func isString(at stackIndex: LuaInt = -1) -> Bool {
        return lua_isstring(luaState, stackIndex) != 0 ? true : false
    }

    /// Returns `true` if the value at the given index is a function (either C or Lua), and `false` otherwise.
    ///  [-0, +0, –]
    public func isFunction(at stackIndex: LuaInt = -1) -> Bool {
        return type(at: stackIndex) == .function
    }

    /// Returns `true` if the value at the given index is a table, and `false` otherwise.
    /// [-0, +0, –]
    public func isTable(at stackIndex: LuaInt = -1) -> Bool {
        return type(at: stackIndex) == .table
    }

    /// Returns `true` if the value at the given index is a light userdata, and `false` otherwise.
    /// [-0, +0, –]
    public func isLightUserData(at stackIndex: LuaInt = -1) -> Bool {
        return type(at: stackIndex) == .lightUserData
    }

    /// Returns `true` if the value at the given index is `nil`, and `true` otherwise.
    /// [-0, +0, –]
    public func isNil(at stackIndex: LuaInt = -1) -> Bool {
        return type(at: stackIndex) == .luaNil
    }

    /// Returns `true` if the value at the given index is a boolean, and `false` otherwise.
    /// [-0, +0, -]
    public func isBoolean(at stackIndex: LuaInt = -1) -> Bool {
        return type(at: stackIndex) == .boolean
    }

    /// Returns `true` if the value at the given index is a thread, and `false` otherwise.
    /// [-0, +0, -]
    public func isThread(at stackIndex: LuaInt = -1) -> Bool {
        return type(at: stackIndex) == .thread
    }

    /// Returns `true` if the given index is not valid, and `false` otherwise.
    /// [-0, +0, -]
    public func isNone(at stackIndex: LuaInt = -1) -> Bool {
        return type(at: stackIndex) == .none
    }

    /// Returns `true` if the given index is not valid or if the value at this index is `nil`, and `false` otherwise.
    /// [-0, +0, -]
    public func isNoneOrNil(at stackIndex: LuaInt = -1) -> Bool {
        return lua_type(luaState, stackIndex) <= 0
    }

    /// Returns `true` if the value at the given index is a C function, and `false` otherwise.
    /// [-0, +0, -]
    public func isCFunction(at stackIndex: LuaInt = -1) -> Bool {
        return lua_iscfunction(luaState, stackIndex) != 0 ? true : false
    }


    /// Returns `true` if the value at the given index is an integer (that is, the value is a number and is represented as an integer), and `false` otherwise.
    /// [-0, +0, -]
    public func isInteger(at stackIndex: LuaInt = -1) -> Bool {
        return lua_isinteger(luaState, stackIndex) != 0 ? true : false
    }

    /// Returns `true` if the value at the given index is a userdata (either full or light), and `false` otherwise.
    /// [-0, +0, -]
    public func isUserData(at stackIndex: LuaInt = -1) -> Bool {
        return lua_isuserdata(luaState, stackIndex) != 0 ? true : false
    }

    /// Returns the type of the value in the given valid index, or `.none` for a non-valid (but acceptable) index.
    /// [-0, +0, -]
    public func type(at stackIndex: LuaInt = -1) -> LuaType {
        return LuaType(rawValue: lua_type(luaState, stackIndex))!
    }


    /// Converts the Lua value at the given index to a `Double`. The Lua value must be a number or a string convertible to a number (see §3.4.3); otherwise, returns `nil`.
    /// [-0, +0, -]
    public func toNumber(at stackIndex: LuaInt = -1) -> Double? {
        var isNum: LuaInt = 0
        let number = lua_tonumberx(luaState, stackIndex, &isNum)
        guard isNum != 0 else { return nil }
        return number
    }

    /// Converts the Lua value at the given index to an `Int`. The Lua value must be an integer, or a number or string convertible to an integer (see §3.4.3); otherwise, returns `nil`.
    /// [-0, +0, -]
    public func toInteger(at stackIndex: LuaInt = -1) -> Int? {
        var isInt: LuaInt = 0
        let i = lua_tointegerx(luaState, stackIndex, &isInt)
        guard isInt != 0 else { return nil }
        return Int(i)
    }

    /// Converts the Lua value at the given index to a `LuaInt`. The Lua value must be an integer, or a number or string convertible to an integer (see §3.4.3); otherwise, returns `nil`.
    /// [-0, +0, -]
    public func toLuaInteger(at stackIndex: LuaInt = -1) -> LuaInt? {
        guard let integer = toInteger(at: stackIndex) else {
            return nil
        }
        return LuaInt(integer)
    }

    /// Converts the Lua value at the given index to a `Bool`. Like all tests in Lua, returns `true` for any Lua value different from `false` and `nil`; otherwise it returns `false`. (If you want to accept only actual boolean values, use `isBoolean()` to test the value's type.)
    /// [-0, +0, -]
    public func toBoolean(at stackIndex: LuaInt = -1) -> Bool {
        return lua_toboolean(luaState, stackIndex) != 0 ? true : false
    }

    /// Converts the Lua value at the given acceptable index to `String`. The Lua value must be a string or a number; otherwise, the function returns `nil`. If the value is a number, then this function also changes the actual value in the stack to a string. (This change confuses `next()` when `toString()` is applied to keys during a table traversal.)
    /// [-0, +0, m]
    public func toString(at stackIndex: LuaInt = -1) throws -> String? {
        guard let luaString = lua_tolstring(luaState, stackIndex, nil) else {
            return nil
        }
        return String(utf8String: luaString)!
    }

    /// Returns the raw "length" of the value at the given index: for strings, this is the string length; for tables, this is the result of the length operator ('#') with no metamethods; for userdata, this is the size of the block of memory allocated for the userdata; for other values, it is 0.
    /// [-0, +0, -]
    public func rawLen(at stackIndex: LuaInt = -1) -> Int {
        return Int(lua_rawlen(luaState, stackIndex))
    }

    /// Converts a value at the given index to a C function. That value must be a C function; otherwise, returns `nil`.
    /// [-0, +0, -]
    public func toCFunction(at stackIndex: LuaInt = -1) -> LuaCFunction? {
        return lua_tocfunction(luaState, stackIndex)
    }

    /// If the value at the given index is a full userdata, returns its block address. If the value is a light userdata, returns its pointer. Otherwise, returns `nil`.
    /// [-0, +0, -]
    public func toUserData(at stackIndex: LuaInt = -1) -> LuaUserData? {
        guard let ptr = lua_touserdata(luaState, stackIndex) else { return nil }
        return ptr
    }

    /// Converts the value at the given index to a Lua thread (represented as a `Lua` instance). This value must be a thread; otherwise, the function returns `nil`.
    /// [-0, +0, -]
    public func toThread(at stackIndex: LuaInt = -1) -> Lua? {
        guard let thread = lua_tothread(luaState, stackIndex) else { return nil }
        return Lua(luaState: thread)
    }

    /// Converts the value at the given index to a generic C pointer (`LuaPointer` aka `UnsafeRawPointer`). The value can be a userdata, a table, a thread, or a function; otherwise, returns `nil`. Different objects will give different pointers. There is no way to convert the pointer back to its original value.
    /// Typically this function is used only for hashing and debug information.
    /// [-0, +0, -]
    public func toPointer(at stackIndex: LuaInt = -1) -> LuaPointer? {
        guard let ptr = lua_topointer(luaState, stackIndex) else { return nil }
        return ptr
    }

    //---------------------------------------------------------
    // MARK: - Comparison and arithmetic
    //---------------------------------------------------------

    /// Performs an arithmetic or bitwise operation over the two values (or one, in the case of negations) at the top of the stack, with the value at the top being the second operand, pops these values, and pushes the result of the operation. The function follows the semantics of the corresponding Lua operator (that is, it may call metamethods).
    /// [-(2|1), +1, throws]
    public func arith(op: LuaOperator) throws {
        // Stack: [operand1] [operand2] | [operand1]
        pushCFunction { luaState in
            // S: ([operand1] [operand2] | [operand1]) [opCode]
            let lua = Lua(luaState: luaState!)
            let op = lua.toLuaInteger()!
            lua.pop()
            // S: [operand1] [operand2] | [operand1]
            lua_arith(luaState, op)
            // S: [result]
            return 1
        }
        // Stack: ([operand1] [operand2] | [operand1]) [Function]
        let operatorArgumentsCount: LuaInt = op.isUnary ? 1 : 2
        rotate(at: -(operatorArgumentsCount + 1), count: 1)
        // Stack: [Function] ([operand1] [operand2] | [operand1])
        pushInteger(Int(op.rawValue))
        // Stack: [Function] ([operand1] [operand2] | [operand1]) [opCode]
        try pcall(argumentsCount: operatorArgumentsCount + 1, resultsCount: 1)
        // Stack: [result]
    }

    /// Returns `true` if the two values in acceptable indices `index1` and `index2` are primitively equal (that is, without calling metamethods). Otherwise returns `false`. Also returns `false` if any of the indices are non valid.
    /// [-0, +0, -]
    public func isRawEqual(stackIndex1: LuaInt = -1, stackIndex2: LuaInt = -2) -> Bool {
        return lua_rawequal(luaState, stackIndex1, stackIndex2) != 0
    }

    /// Compares two Lua values. Returns `true` if the value at index `index1` satisfies op when compared with the value at index `index2`, following the semantics of the corresponding Lua operator (that is, it may call metamethods). Otherwise returns `false`. Also returns `false` if any of the indices is not valid.
    /// [-0, +0, throws]
    public func isComparable(stackIndex1: LuaInt, stackIndex2: LuaInt, by comparison: LuaComparison) throws -> Bool {
        // Stack: [value1] ... [value2] ...
        let absIndex1 = absIndex(of: stackIndex1)
        let absIndex2 = absIndex(of: stackIndex2)
        pushCFunction { luaState in
            // S: [value1] [value2] [comparison]
            let lua = Lua(luaState: luaState!)
            let comparison = lua.toLuaInteger(at: 3)!
            let result = lua_compare(luaState, 1, 2, comparison) != 0 ? true : false
            lua.pushBoolean(result)
            // S: [value1] [value2] [comparison] [result]
            return 1
        }
        // Stack: [value1] ... [value2] ... [function]
        pushValue(at: absIndex1)
        // Stack: ... [value2] ... [function] [value1]
        pushValue(at: absIndex2)
        // Stack: ... [function] [value1] [value2]
        pushInteger(Int(comparison.rawValue))
        // Stack: ... [function] [value1] [value2] [comparison]
        try pcall(argumentsCount: 3, resultsCount: 1)
        // Stack: ... [Result]
        let result = toBoolean()
        pop()
        // Stack: ...
        return result
    }

    //---------------------------------------------------------
    // MARK: - Push functions (Swift -> stack)
    //---------------------------------------------------------

    /// Pushes a `nil` value onto the stack.
    /// [-0, +1, -]
    public func pushNil() {
        lua_pushnil(luaState)
    }

    /// Pushes a number with value `n` onto the stack.
    /// [-0, +1, -]
    public func pushNumber(_ n: Double) {
        lua_pushnumber(luaState, n)
    }

    // Pushes a integer with value `n` onto the stack.
    /// [-0, +1, -]
    public func pushInteger(_ n: Int) {
        lua_pushinteger(luaState, Int64(n))
    }

    // Pushes a `LuaInt` with value `n` onto the stack.
    public func pushLuaInteger(_ n: LuaInt) {
        lua_pushinteger(luaState, Int64(n))
    }

    // Pushes the string `s` onto the stack.
    /// [-0, +1, m]
    public func pushString(_ s: String) {
        lua_pushstring(luaState, s.luaString)
    }

    /// Pushes a boolean value with value `b` onto the stack.
    /// [-0, +1, -]
    public func pushBoolean(_ b: Bool) {
        lua_pushboolean(luaState, b ? 1 : 0)
    }

    /// Pushes a new C closure onto the stack.
    /// When a C function is created, it is possible to associate some values with it, thus creating a C closure (see §4.4); these values are then accessible to the function whenever it is called. To associate values with a C function, first these values must be pushed onto the stack (when there are multiple values, the first value is pushed first). Then `pushClosure` is called to create and push the C function onto the stack, with the argument `valuesCount` telling how many values will be associated with the function. `pushClosure` also pops these values from the stack.
    /// The maximum value for `valuesCount` is 255.
    /// [-n, +1, m]
    public func pushClosure(valuesCount: LuaInt, fn: @escaping LuaCFunction) {
        lua_pushcclosure(luaState, fn, valuesCount)
    }

    /// Pushes a C function onto the stack. This function receives a pointer to a C function and pushes onto the stack a Lua value of type function that, when called, invokes the corresponding C function.
    /// Any function to be callable by Lua must follow the correct protocol to receive its parameters and return its results (see lua_CFunction).
    /// [-0, +1, m]
    public func pushCFunction(fn: @escaping LuaCFunction) {
        pushClosure(valuesCount: 0, fn: fn)
    }

//    public func callFunction(argumentsCount: LuaInt, resultsCount: LuaInt, fn: @escaping LuaFunction) throws {
//        // Stack: [arg1] ... [argN]
//
//        final class Box {
//            let fn: LuaFunction
//            init(_ fn: @escaping LuaFunction) { self.fn = fn }
//        }
//
//        let box = Box(fn)
//
//        let pbox = Unmanaged.passRetained(box).toOpaque()
//        pushLightUserData(pbox)
//        // Stack: [arg1] ... [argN] [pbox]
//
//        let closureArgumentsCount = argumentsCount + 1
//
//        pushClosure(valuesCount: closureArgumentsCount) { luaState in
//            // S: [arg1] ... [argN] [pbox]
//            let lua = Lua(luaState: luaState!)
//            let pbox = lua.toLightUserData()
//            do {
//                let box = Unmanaged<Box>.fromOpaque(p).takeRetainedValue()
//                return try box.fn(lua)
//            } catch {
//                lua_error(luaState)
//            }
//        }
//        // Stack: [closure]
//        rotate(at: -closureArgumentsCount, count: 1)
//        // Stack: [closure] [arg1] ... [argN] [pbox]
//        try pcall(argumentsCount: closureArgumentsCount, resultsCount: resultsCount)
//    }

    /// Pushes a light userdata onto the stack.
    /// Userdata represent C values in Lua. A light userdata represents a pointer, a `LuaUserData` AKA `UnsafeMutableRawPointer`. It is a value (like a number): you do not create it, it has no individual metatable, and it is not collected (as it was never created). A light userdata is equal to "any" light userdata with the same C address.
    /// [-0, +1, -]
    public func pushLightUserData(_ p: LuaUserData) {
        lua_pushlightuserdata(luaState, p)
    }

    /// Pushes the thread represented by a `Lua` instance onto the stack. Returns `true` if this thread is the main thread of its state.
    /// [-0, +1, -]
    @discardableResult public func pushThread(_ t: Lua) -> Bool {
        return lua_pushthread(t.luaState) != 0 ? true : false
    }

    //---------------------------------------------------------
    // MARK: - Get functions (Lua -> stack)
    //---------------------------------------------------------

    /// Pushes onto the stack the value of the global `name`.
    /// Returns the type of the pushed value.
    /// [-0, +1, throws]
    @discardableResult public func getGlobal(named name: String) throws -> LuaType {
        // Stack: ...
        pushCFunction { luaState in
            // S: [name]
            let lua = Lua(luaState: luaState!)
            let name = try! lua.toString()
            lua_getglobal(luaState, name)
            // S: [name] [value]
            return 1
        }
        // Stack: ... [function]
        pushString(name)
        // Stack: ... [function] [name]
        try pcall(argumentsCount: 1, resultsCount: 1)
        // Stack: [result]
        return type()
    }

    /// Pushes onto the stack the value `t[k]`, where `t` is the value at the given valid `index` and `k` is the value at the top of the stack.
    /// This function pops the key from the stack (putting the resulting value in its place).
    /// As in Lua, this function may trigger a metamethod for the `index` event (see §2.8).
    /// If `isRaw` is `true`, does a raw access (i.e., without metamethods).
    /// isRaw: [-1, +1, -] else [-1, +1, throws]
    @discardableResult public func getInTable(at stackIndex: LuaInt, isRaw: Bool = false) throws -> LuaType {
        // Stack: [table] ... [key]
        if isRaw {
            return LuaType(rawValue: lua_rawget(luaState, stackIndex))!
        } else {
            dup(at: stackIndex)
            // Stack: [table] ... [key] [table]
            swap()
            // Stack: ... [table] [key]
            pushCFunction { luaState in
                // S: [table] [key]
                lua_gettable(luaState, 1)
                return 1
            }
            // Stack: ... [table] [key] [function]
            insert(at: -3)
            // Stack: ... [function] [table] [key]
            try pcall(argumentsCount: 2, resultsCount: 1)
            // Stack: ... [result]
            return type()
        }
    }

    /// Pushes onto the stack the value `t[k]`, where `t` is the value at the given valid `index`. As in Lua, this function may trigger a metamethod for the `index` event (see §2.8).
    /// Returns the type of the pushed value.
    /// [-0, +1, throws]
    @discardableResult public func getFieldInTable(at stackIndex: LuaInt, named key: String) throws -> LuaType {
        let tableIndex = absIndex(of: stackIndex)
        // Stack: [table] ...
        pushString(key)
        // Stack: [table] ... [key]
        return try getInTable(at: tableIndex)
        // Stack: ... [result]
    }

    /// Pushes onto the stack the value `t[i]`, where `t` is the value at the given index. As in Lua, this function may trigger a metamethod for the `index` event (see §2.4).
    /// Returns the type of the pushed value.
    /// If `isRaw` is `true`, does a raw access (i.e., without metamethods).
    /// isRaw: [-0, +1, -], else [-0, +1, throws]
    @discardableResult public func getIndexInTable(at stackIndex: LuaInt, for index: Int, isRaw: Bool = false) throws -> LuaType {
        if isRaw {
            return LuaType(rawValue: lua_rawgeti(luaState, stackIndex, Int64(index)))!
        } else {
            let tableIndex = absIndex(of: stackIndex)
            // Stack: [table] ...
            pushInteger(index)
            // Stack: [table] ... [index]
            return try getInTable(at: tableIndex)
            // Stack: ... [result]
        }
    }

    /// Pushes onto the stack the value t[k], where t is the table at the given index and k is the pointer p represented as a light userdata. The access is raw; that is, it does not invoke the __index metamethod.
    /// Returns the type of the pushed value.
    /// [-0, +1, -]
    @discardableResult public func rawGetP(at stackIndex: LuaInt = -1, p: LuaUserData) -> LuaType {
        return LuaType(rawValue: lua_rawgetp(luaState, stackIndex, p))!
    }

    /// Creates a new empty table and pushes it onto the stack. Parameter narr is a hint for how many elements the table will have as a sequence; parameter nrec is a hint for how many other elements the table will have. Lua may use these hints to preallocate memory for the new table. This preallocation is useful for performance when you know in advance how many elements the table will have. Otherwise you can use the function lua_newtable.
    /// [-0, +1, m]
    public func newTable(narr: LuaInt = 0, nrec: LuaInt = 0) {
        lua_createtable(luaState, narr, nrec)
    }

    // If the value at the given index has a metatable, the function pushes that metatable onto the stack and returns `true`. Otherwise, the function returns `false` and pushes nothing on the stack.
    // [-0, +(0|1), -]
    @discardableResult public func getMetatable(at stackIndex: LuaInt = -1) -> Bool {
        return lua_getmetatable(luaState, stackIndex) != 0 ? true : false
    }

    //---------------------------------------------------------
    // MARK: - Set functions (stack -> Lua)
    //---------------------------------------------------------

    /// Pops a value from the stack and sets it as the new value of global name.
    /// [-1, +0, throws]
    public func setGlobal(name: String) throws {
        // Stack: ... [value]
        pushCFunction { luaState in
            // S: [value] [name]
            let lua = Lua(luaState: luaState!)
            let name = try! lua.toString(at: 2)
            lua.pop()
            // S: [value]
            lua_setglobal(luaState, name)
            return 0
        }
        // Stack: ... [value] [function]
        swap()
        // Stack: ... [function] [value]
        pushString(name)
        // Stack: ... [function] [value] [name]
        try pcall(argumentsCount: 2, resultsCount: 0)
        // Stack: ...
    }

    /// Does the equivalent to t[k] = v, where t is the value at the given index, v is the value at the top of the stack, and k is the value just below the top.
    /// This function pops both the key and the value from the stack. As in Lua, this function may trigger a metamethod for the "newindex" event (see §2.4).
    /// If `isRaw` is `true`, does a raw assignment (i.e., without metamethods).
    /// [-2, +0, throws]
    public func setInTable(at stackIndex: LuaInt, isRaw: Bool = false) throws {
        // Stack: [table] ... [key] [value]
        if isRaw {
            lua_rawset(luaState, stackIndex)
        } else {
            pushValue(at: stackIndex)
            // Stack: [table] ... [key] [value] [table]
            insert(at: -3)
            // Stack: ... [table] [key] [value]
            pushCFunction { luaState in
                // S: [table] [key] [value]
                lua_settable(luaState, -3)
                return 0
            }
            // Stack: ... [table] [key] [value] [Function]
            insert(at: -4)
            // Stack: ... [Function] [table] [key] [value]
            try pcall(argumentsCount: 3, resultsCount: 0)
            // Stack: ...
        }
    }

    /// Does the equivalent to t[k] = v, where t is the value at the given index and v is the value at the top of the stack.
    /// This function pops the value from the stack. As in Lua, this function may trigger a metamethod for the "newindex" event (see §2.4)
    /// If `isRaw` is `true`, does a raw assignment (i.e., without metamethods).
    /// [-1, +0, throws]
    public func setFieldInTable(at stackIndex: LuaInt, named key: String, isRaw: Bool = false) throws {
        // Stack: [table] ... [value]
        pushString(key)
        // Stack: [table] ... [value] [key]
        swap()
        // Stack: [table] ... [key] [value]
        try setInTable(at: stackIndex, isRaw: isRaw)
        // Stack: ...
    }

    /// Does the equivalent to t[k] = v, where t is the value at the given index and v is the value at the top of the stack.
    /// This function pops the value from the stack. As in Lua, this function may trigger a metamethod for the "newindex" event (see §2.4)
    /// If `isRaw` is `true`, does a raw assignment (i.e., without metamethods).
    /// [-1, +0, throws]
    public func setIndexInTable(at stackIndex: LuaInt, index: Int, isRaw: Bool = false) throws {
        // Stack: [table] ... [value]
        pushInteger(index)
        // Stack: [table] ... [value] [index]
        swap()
        // Stack: [table] ... [index] [value]
        try setInTable(at: stackIndex, isRaw: isRaw)
        // Stack: ...
    }

    /// Does the equivalent to t[n] = v, where t is the value at the given index and v is the value at the top of the stack.
    /// This function pops the value from the stack. As in Lua, this function may trigger a metamethod for the "newindex" event (see §2.4).
    /// If `isRaw` is `true`, does a raw assignment (i.e., without metamethods).

    //---------------------------------------------------------
    // MARK: - Load and Call functions (load and run Lua code)
    //---------------------------------------------------------

    // [-(argumentsCount + 1), +resultsCount, e]
    public func call(argumentsCount: LuaInt, resultsCount: LuaInt, continuationContext: LuaContinuationContext, continuationFunction: @escaping LuaContinuationFunction) {
        lua_callk(luaState, argumentsCount, resultsCount, continuationContext, continuationFunction)
    }

    // [-(argumentsCount + 1), +resultsCount, e]
    public func call(argumentsCount: LuaInt, resultsCount: LuaInt) {
        lua_callk(luaState, argumentsCount, resultsCount, 0, nil)
    }

    // [-(argumentsCount + 1), +(resultsCount|1), –]
    public func pcall(argumentsCount: LuaInt, resultsCount: LuaInt, errfuncIndex: LuaInt = 0, continuationContext: LuaContinuationContext, continuationFunction: @escaping LuaContinuationFunction) throws {
        return try checkStatus(lua_pcallk(luaState, argumentsCount, resultsCount, errfuncIndex, continuationContext, continuationFunction))
    }

    // [-(argumentsCount + 1), +(resultsCount|1), –]
    public func pcall(argumentsCount: LuaInt, resultsCount: LuaInt, errfuncIndex: LuaInt = 0) throws {
        return try checkStatus(lua_pcallk(luaState, argumentsCount, resultsCount, errfuncIndex, 0, nil))
    }

    //---------------------------------------------------------
    // MARK: - Miscellaneous functions
    //---------------------------------------------------------

    // Generates a Lua error, using the value at the top of the stack as the error object. This function never returns.
    // [-1, +0, v]
    public func raiseError() -> Never {
        let luaError = unsafeBitCast(lua_error, to: ((UnsafeMutablePointer<lua_State>?) -> Never).self)
        luaError(luaState)
    }

    // Generates a Lua error, using the given String as the error object. This function never returns.
    // [-0, +0, v]
    public func raiseError(_ message: String) -> Never {
        pushString(message)
        raiseError()
    }

    //---------------------------------------------------------
    // MARK: - Debug
    //---------------------------------------------------------

    // [-0, +0, -]
    public var stackDescription: String {
        var items = [String]()

        if isEmpty {
            items.append("empty")
        } else {
            for i in 1 ... count {
                let s: String
                switch type(at: i) {
                case .boolean:
                    s = toBoolean(at: i) ? "true" : "false"
                case .function:
                    s = "Function"
                case .lightUserData:
                    s = "LightUserData"
                case .luaNil:
                    s = "nil"
                case .none:
                    fatalError() // represents invalid index-- should never hapen
                case .number:
                    if isInteger(at: i) {
                        s = String(toInteger(at: i)!)
                    } else {
                        s = String(toNumber(at: i)!)
                    }
                case .string:
                    s = try! "'\(toString(at: i)!)'"
                case .table:
                    s = "Table"
                case .thread:
                    s = "Thread"
                case .userData:
                    s = "UserData"
                }
                items.append("[\(s)]")
            }
        }

        return items.joined(separator: " ")
    }

    // [-0, +0, -]
    public func printStack() {
        print(stackDescription)
    }
}
